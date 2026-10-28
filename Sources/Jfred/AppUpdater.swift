import Foundation
import JfredCore

// Update checks read public GitHub releases for weijing24/Jfred and send only
// the app version. A download is installed only after the checksum, bundle id,
// version and code signature match that release.

enum UpdatePhase: Equatable {
    case idle
    case checking
    case current
    case available
    case downloading
    case installing
    case failed(String)
}

enum UpdateInstallError: Error {
    case message(String)

    static func text(_ error: Error) -> String {
        if case .message(let text) = error as? UpdateInstallError { return text }
        return "The update didn't finish. Check the network and try again."
    }
}

private enum UpdateTraffic {
    case api
    case asset(version: String, architecture: String)
}

private final class UpdateRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let traffic: UpdateTraffic

    init(traffic: UpdateTraffic) {
        self.traffic = traffic
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        guard let url = request.url, url.scheme == "https", url.port == nil, let host = url.host else { return nil }
        switch traffic {
        case .api:
            guard AppUpdateFeed.isAllowedAPIHost(host) else { return nil }
            return request
        case .asset(let version, let architecture):
            if host.lowercased() == "github.com" {
                guard AppUpdateFeed.isOfficialAssetURL(url, version: version, architecture: architecture) else { return nil }
                return request
            }
            guard AppUpdateFeed.isAllowedAssetHost(host) else { return nil }
            return request
        }
    }
}

enum UpdateLog {
    private static let lock = NSLock()

    static func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Jfred", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let url = logs.appendingPathComponent("update.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        let stamp = ISO8601DateFormatter().string(from: Date())
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data("\(stamp) \(line)\n".utf8))
    }
}

enum AppUpdater {
    static func fetchReleaseFeed(version: String) async throws -> Data {
        let redirect = UpdateRedirectGuard(traffic: .api)
        let session = session(delegate: redirect, requestTimeout: 30)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: AppUpdateFeed.releasesURL())
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(userAgent(version), forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateInstallError.message("Couldn't check for updates. Check the network and try again.")
        }
        guard let host = response.url?.host, AppUpdateFeed.isAllowedAPIHost(host) else {
            throw UpdateInstallError.message("Couldn't check for updates. Check the network and try again.")
        }
        guard data.count <= AppUpdateFeed.maxFeedBytes else { throw UpdateFeedError.malformed }
        return data
    }

    static func download(_ asset: UpdateAsset, version: String, architecture: String) async throws -> URL {
        guard asset.name == AppUpdateFeed.assetName(version: version, architecture: architecture) else {
            throw UpdateInstallError.message("The release asset is not a Jfred disk image.")
        }
        guard AppUpdateFeed.isOfficialAssetURL(asset.downloadURL, version: version, architecture: architecture) else {
            throw UpdateInstallError.message("The release asset is not a Jfred disk image.")
        }
        let redirect = UpdateRedirectGuard(traffic: .asset(version: version, architecture: architecture))
        let session = session(delegate: redirect, requestTimeout: 180)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: asset.downloadURL)
        request.timeoutInterval = 180
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(userAgent(version), forHTTPHeaderField: "User-Agent")
        let (temp, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateInstallError.message("Couldn't download the update. Check the network and try again.")
        }
        guard let host = response.url?.host, AppUpdateFeed.isAllowedAssetHost(host) else {
            throw UpdateInstallError.message("Couldn't download the update. Check the network and try again.")
        }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("JfredDownload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let destination = folder.appendingPathComponent(asset.name)
        do {
            try FileManager.default.moveItem(at: temp, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw UpdateInstallError.message("Couldn't download the update. Check the network and try again.")
        }
        let size = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        guard size > 0, size <= AppUpdateFeed.maxAssetBytes, size == asset.byteCount else {
            try? FileManager.default.removeItem(at: folder)
            throw UpdateInstallError.message("The download size didn't match the published release.")
        }
        return destination
    }

    private static func userAgent(_ version: String) -> String {
        "Jfred/\(version) (Macintosh; update)"
    }

    private static func session(delegate: URLSessionTaskDelegate, requestTimeout: TimeInterval) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }
}

enum UpdateInstaller {
    static func runningBundle() throws -> URL {
        let bundle = Bundle.main.bundleURL.standardizedFileURL
        let path = bundle.path
        if path.contains("/AppTranslocation/") {
            throw UpdateInstallError.message("macOS opened a temporary copy. Move Jfred.app to the Applications folder, open that copy, then update.")
        }
        if path.hasPrefix("/Volumes/") {
            throw UpdateInstallError.message("Jfred is running from a disk image. Copy it to the Applications folder, open that copy, then update.")
        }
        guard UpdatePaths.isInstallableBundlePath(path) else {
            throw UpdateInstallError.message("This copy isn't a Jfred.app bundle. Move Jfred into the Applications folder, then update.")
        }
        let values = try bundle.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values.isSymbolicLink == true {
            throw UpdateInstallError.message("Jfred.app is a shortcut. Open the real app and update that copy.")
        }
        let parent = bundle.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            throw UpdateInstallError.message("Jfred can't replace itself in this folder. Move it to the Applications folder, then update.")
        }
        return bundle
    }

    static func apply(dmg: URL, release: UpdateRelease, bundle: URL) throws {
        let folder = dmg.deletingLastPathComponent()
        defer {
            try? FileManager.default.removeItem(at: dmg)
            if folder.lastPathComponent.hasPrefix("JfredDownload-") {
                try? FileManager.default.removeItem(at: folder)
            }
        }
        guard UpdateChecksum.matches(file: dmg, sha256: release.asset.sha256) else {
            throw UpdateInstallError.message("The download didn't match the published checksum.")
        }
        guard UpdatePaths.isInstallableBundlePath(bundle.path) else {
            throw UpdateInstallError.message("This copy isn't a Jfred.app bundle. Move Jfred into the Applications folder, then update.")
        }
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("JfredUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var keepWork = false
        defer { if !keepWork { try? FileManager.default.removeItem(at: work) } }
        let mount = work.appendingPathComponent("mnt", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        var mounted = false
        defer {
            if mounted {
                _ = run("/usr/sbin/diskutil", ["eject", "force", mount.path], timeout: 30)
            }
        }
        guard run("/usr/sbin/diskutil", ["image", "attach", "--mountOptions", "nobrowse", "--readOnly", "--mountPoint", mount.path, dmg.path], timeout: 60) == 0 else {
            throw UpdateInstallError.message("Couldn't open the downloaded disk image.")
        }
        mounted = true
        let source = mount.appendingPathComponent("Jfred.app")
        try validateApp(source, version: release.version)
        let staged = work.appendingPathComponent("Jfred.app")
        guard run("/usr/bin/ditto", [source.path, staged.path], timeout: 60) == 0 else {
            throw UpdateInstallError.message("Couldn't read Jfred.app from the disk image.")
        }
        _ = run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", staged.path], timeout: 20)
        try validateApp(staged, version: release.version)
        guard run("/usr/bin/codesign", ["--verify", "--deep", "--strict", staged.path], timeout: 30) == 0 else {
            throw UpdateInstallError.message("The downloaded app failed signature verification.")
        }
        _ = run("/usr/sbin/diskutil", ["eject", "force", mount.path], timeout: 30)
        mounted = false
        try launchSwap(staged: staged, bundle: bundle)
        keepWork = true
    }

    private static func validateApp(_ app: URL, version: String) throws {
        let values = try app.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard values.isSymbolicLink != true, values.isDirectory == true else {
            throw UpdateInstallError.message("The disk image doesn't contain Jfred.app.")
        }
        let plistURL = app.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            throw UpdateInstallError.message("The disk image doesn't contain Jfred.app.")
        }
        guard plist["CFBundleIdentifier"] as? String == AppUpdateFeed.bundleIdentifier else {
            throw UpdateInstallError.message("The downloaded app is not this copy of Jfred.")
        }
        guard plist["CFBundleExecutable"] as? String == "Jfred" else {
            throw UpdateInstallError.message("The downloaded app is not this copy of Jfred.")
        }
        guard plist["CFBundleShortVersionString"] as? String == version else {
            throw UpdateInstallError.message("The disk image version didn't match the release.")
        }
        guard version == AppUpdateFeed.version(fromTag: "v\(version)") else {
            throw UpdateInstallError.message("The disk image version didn't match the release.")
        }
        let binary = app.appendingPathComponent("Contents/MacOS/Jfred")
        let binaryValues = try binary.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
        guard binaryValues.isSymbolicLink != true, binaryValues.isRegularFile == true else {
            throw UpdateInstallError.message("The disk image doesn't contain Jfred.app.")
        }
        guard FileManager.default.isExecutableFile(atPath: binary.path) else {
            throw UpdateInstallError.message("The disk image doesn't contain Jfred.app.")
        }
    }

    private static func launchSwap(staged: URL, bundle: URL) throws {
        guard staged.lastPathComponent == "Jfred.app", bundle.lastPathComponent == "Jfred.app" else {
            throw UpdateInstallError.message("This copy isn't a Jfred.app bundle. Move Jfred into the Applications folder, then update.")
        }
        let stage = staged.deletingLastPathComponent()
        guard stage.lastPathComponent.hasPrefix("JfredUpdate-") else {
            throw UpdateInstallError.message("The update didn't finish. Check the network and try again.")
        }
        guard isSafePath(staged.path), isSafePath(bundle.path), staged.path != bundle.path else {
            throw UpdateInstallError.message("This copy isn't a Jfred.app bundle. Move Jfred into the Applications folder, then update.")
        }
        let log = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Jfred/update.log")
        try? FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let scriptURL = stage.appendingPathComponent("swap.sh")
        try Data(swapScript.utf8).write(to: scriptURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path, String(ProcessInfo.processInfo.processIdentifier), staged.path, bundle.path, log.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw UpdateInstallError.message("Couldn't switch to the new copy of Jfred.")
        }
    }

    private static func isSafePath(_ path: String) -> Bool {
        path.hasPrefix("/") && !path.contains("\n") && !path.contains("\r") && !path.contains("\0")
    }

    @discardableResult
    private static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return 1
        }
        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in group.leave() }
        if group.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            _ = group.wait(timeout: .now() + 1)
            return 124
        }
        return process.terminationStatus
    }

    private static let swapScript = #"""
    #!/bin/bash
    set -u
    trap '' HUP
    pid="$1"
    src="$2"
    dest="$3"
    log="$4"
    mkdir -p "$(dirname "$log")"
    exec >>"$log" 2>&1
    echo "start $(date)"
    case "$dest" in
      */Jfred.app) ;;
      *) echo "refusing destination"; exit 1 ;;
    esac
    case "$src" in
      */Jfred.app) ;;
      *) echo "refusing source"; exit 1 ;;
    esac
    if [ "$src" = "$dest" ]; then
      echo "source and destination are the same"
      exit 1
    fi
    stage="$(dirname "$src")"
    case "$(basename "$stage")" in
      JfredUpdate-*) ;;
      *) echo "refusing stage"; exit 1 ;;
    esac
    ready=0
    i=0
    while [ "$i" -lt 120 ]; do
      if ! kill -0 "$pid" 2>/dev/null; then
        ready=1
        break
      fi
      i=$((i + 1))
      sleep 0.25
    done
    if [ "$ready" != "1" ]; then
      echo "timed out waiting for $pid"
      exit 1
    fi
    sleep 0.4
    parent="$(dirname "$dest")"
    backup="$parent/Jfred.app.previous"
    /bin/rm -rf "$backup"
    if ! /bin/mv "$dest" "$backup"; then
      echo "could not move the current app aside"
      exit 1
    fi
    if /usr/bin/ditto "$src" "$dest"; then
      /usr/bin/xattr -dr com.apple.quarantine "$dest" || true
      if ! /usr/bin/open "$dest"; then
        echo "open failed"
      fi
      /bin/rm -rf "$backup"
      /bin/rm -rf "$stage"
      echo "updated"
    else
      echo "copy failed, restoring"
      /bin/rm -rf "$dest"
      /bin/mv "$backup" "$dest" || true
      /usr/bin/open "$dest" || true
      exit 1
    fi
    """#
}
