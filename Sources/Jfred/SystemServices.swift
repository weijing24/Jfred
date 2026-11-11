import JfredCore
import AppKit
import ApplicationServices
import CoreServices
import Darwin
import Foundation

final class ShellBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ chunk: Data) {
        lock.lock()
        if data.count < 400_000 { data.append(chunk) }
        lock.unlock()
    }

    func snapshot() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

enum Shell {
    static func run(
        _ executable: String,
        _ arguments: [String],
        timeout: TimeInterval = 4,
        directory: URL? = nil,
        environment: [String: String]? = nil
    ) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let directory { process.currentDirectoryURL = directory }
        if let environment { process.environment = environment }
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        let collected = ShellBuffer()
        let handle = out.fileHandleForReading
        handle.readabilityHandler = { file in
            let chunk = file.availableData
            guard !chunk.isEmpty else { return }
            collected.append(chunk)
        }
        do { try process.run() } catch { return "" }
        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in group.leave() }
        if group.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            _ = group.wait(timeout: .now() + 0.6)
        }
        handle.readabilityHandler = nil
        return String(data: collected.snapshot(), encoding: .utf8) ?? ""
    }

    static func osascript(_ source: String, timeout: TimeInterval = 4) -> String {
        run("/usr/bin/osascript", ["-e", source], timeout: timeout)
    }
}

/// Runs the shell and AppleScript commands the launcher sends on the user's
/// behalf (system commands, Finder, Terminal). Each can block for its whole
/// timeout, so they run here instead of on the main thread: one at a time, in
/// the order they were asked for, so pressing volume up twice adds 20.
enum CommandQueue {
    private static let queue = DispatchQueue(label: "dev.jim.jfred.commands", qos: .userInitiated)

    static func run(_ work: @escaping @Sendable () -> Void) {
        queue.async(execute: work)
    }
}

/// System commands that spawn a process, run AppleScript or wait on a disk.
/// Call from `CommandQueue`, never from the main thread.
enum SystemEffectRunner {
    static func perform(_ effect: SystemEffect, ejectExclusions: [String]) {
        switch effect {
        case .setOutputVolume(let value):
            _ = Shell.osascript("set volume output volume \(value)")
        case .sleep: _ = Shell.osascript("tell application \"System Events\" to sleep")
        case .restart: _ = Shell.osascript("tell application \"System Events\" to restart")
        case .shutdown: _ = Shell.osascript("tell application \"System Events\" to shut down")
        case .logout: _ = Shell.osascript("tell application \"System Events\" to log out")
        case .lock: _ = Shell.osascript("tell application \"System Events\" to keystroke \"q\" using {command down, control down}")
        case .screensaver: _ = Shell.run("/usr/bin/open", ["-a", "ScreenSaverEngine"])
        case .emptyTrash: _ = Shell.osascript("tell application \"Finder\" to empty trash")
        case .showTrash: _ = Shell.run("/usr/bin/open", [NSHomeDirectory() + "/.Trash"])
        case .eject(let all):
            ejectDisks(all: all, exclusions: ejectExclusions)
        case .toggleDarkMode:
            _ = Shell.osascript("tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode")
        case .toggleHiddenFiles:
            let current = Shell.run("/usr/bin/defaults", ["read", "com.apple.finder", "AppleShowAllFiles"])
            let next = current.trimmingCharacters(in: .whitespacesAndNewlines) == "1" ? "false" : "true"
            _ = Shell.run("/usr/bin/defaults", ["write", "com.apple.finder", "AppleShowAllFiles", "-bool", next])
            _ = Shell.run("/usr/bin/killall", ["Finder"])
        case .mute: _ = Shell.osascript("set volume with output muted")
        case .volumeUp: changeVolume(10)
        case .volumeDown: changeVolume(-10)
        case .quitAll, .showDesktop, .missionControl, .launchpad, .screenshot, .unknown:
            // Not `runsOnCommandQueue`; AppModel performs these itself.
            break
        }
    }

    private static func ejectDisks(all: Bool, exclusions: [String]) {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsEjectableKey, .volumeIsLocalKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.volumeIsEjectable == true else { continue }
            if !all, values.volumeIsLocal == false { continue }
            let name = values.volumeName ?? url.lastPathComponent
            if exclusions.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) { continue }
            try? NSWorkspace.shared.unmountAndEjectDevice(at: url)
        }
    }

    private static func changeVolume(_ delta: Int) {
        let text = Shell.osascript("output volume of (get volume settings)")
        let current = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 50
        let next = min(100, max(0, current + delta))
        _ = Shell.osascript("set volume output volume \(next)")
    }
}

enum AppIndexer {
    static func watchPaths(preferences: Preferences) -> [String] {
        roots(preferences: preferences).map(\.0).filter { FileManager.default.fileExists(atPath: $0) }
    }

    private static func roots(preferences: Preferences) -> [(String, Int)] {
        var roots: [(String, Int)] = []
        if preferences.includeSystemApps || preferences.scopeApplications {
            roots.append(("/Applications", 4))
            roots.append(("/System/Applications", 4))
        }
        if preferences.includeUserApps {
            roots.append(((NSHomeDirectory() as NSString).appendingPathComponent("Applications"), 4))
        }
        if preferences.includePreferencePanes {
            roots.append(("/Library/PreferencePanes", 1))
            roots.append(("/System/Library/PreferencePanes", 1))
            roots.append(((NSHomeDirectory() as NSString).appendingPathComponent("Library/PreferencePanes"), 1))
        }
        for path in preferences.scopePaths {
            roots.append(((path as NSString).expandingTildeInPath, 4))
        }
        return roots
    }

    /// Finder lives in CoreServices, which is not scanned. Keep it searchable.
    private static func finderRecord() -> AppRecord? {
        let path = "/System/Library/CoreServices/Finder.app"
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return AppRecord(id: path, name: "Finder", path: path, aliases: matchFields(forName: "Finder"))
    }

    static func applications(preferences: Preferences) -> [AppRecord] {
        let roots = roots(preferences: preferences)
        var seen = Set<String>()
        var apps: [AppRecord] = []
        for (root, depth) in roots {
            for app in scan(root: root, maxDepth: depth) where seen.insert(app.path).inserted {
                apps.append(app)
            }
        }
        if preferences.includeSystemApps, let finder = finderRecord(), seen.insert(finder.path).inserted {
            apps.append(finder)
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func scan(root: String, maxDepth: Int) -> [AppRecord] {
        let rootURL = URL(fileURLWithPath: root)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue else { return [] }
        guard let enumerator = FileManager.default.enumerator(at: rootURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        let rootCount = rootURL.pathComponents.count
        var results: [AppRecord] = []
        while let url = enumerator.nextObject() as? URL {
            if results.count >= 4000 { break }
            let depth = url.pathComponents.count - rootCount
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }
            let ext = url.pathExtension.lowercased()
            if ext == "app" || ext == "prefpane" {
                let resolved = resolvedBundle(url)
                var name = FileManager.default.displayName(atPath: resolved.path)
                for suffix in [".app", ".prefPane", ".prefpane"] where name.hasSuffix(suffix) {
                    name = String(name.dropLast(suffix.count))
                }
                if ext == "prefpane" {
                    name = PreferencePaneNames.displayName(for: resolved, fallback: name)
                }
                let aliases = bundleAliases(for: resolved, displayName: name)
                results.append(AppRecord(id: resolved.path, name: name, path: resolved.path, aliases: aliases))
                enumerator.skipDescendants()
                continue
            }
            let last = url.lastPathComponent
            if last == "node_modules" || last == ".git" {
                enumerator.skipDescendants()
            }
        }
        return results
    }


    private static func bundleAliases(for url: URL, displayName: String) -> [String] {
        var aliases: [String] = []
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        if let data = try? Data(contentsOf: plistURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            for key in ["CFBundleName", "CFBundleDisplayName"] {
                if let value = plist[key] as? String {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty,
                       trimmed.caseInsensitiveCompare(displayName) != .orderedSame,
                       !aliases.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                        aliases.append(trimmed)
                    }
                }
            }
        }
        return Array(matchFields(forName: displayName, aliases: aliases).dropFirst())
    }

    private static func resolvedBundle(_ url: URL) -> URL {
        if let values = try? url.resourceValues(forKeys: [.isAliasFileKey, .isSymbolicLinkKey]) {
            if values.isAliasFile == true, let destination = try? URL(resolvingAliasFileAt: url) {
                return destination
            }
            if values.isSymbolicLink == true {
                return url.resolvingSymlinksInPath()
            }
        }
        return url
    }
}

enum PreferencePaneNames {
    private static let mapped: [String: String] = [
        "Accounts.prefPane": "Users & Groups",
        "AppleIDPrefPane.prefPane": "Apple ID",
        "Appearance.prefPane": "Appearance",
        "DateAndTime.prefPane": "Date & Time",
        "DesktopScreenEffectsPref.prefPane": "Desktop & Screen Saver",
        "FamilySharingPrefPane.prefPane": "Family",
        "PrintAndScan.prefPane": "Printers & Scanners",
        "PrivacyAndSecurity.prefPane": "Privacy & Security",
        "SharingPref.prefPane": "Sharing",
        "TouchID.prefPane": "Touch ID",
        "UniversalAccessPref.prefPane": "Accessibility",
        "Notifications.prefPane": "Notifications",
        "Sound.prefPane": "Sound",
        "Network.prefPane": "Network",
        "Bluetooth.prefPane": "Bluetooth",
        "Battery.prefPane": "Battery",
        "Displays.prefPane": "Displays",
        "Trackpad.prefPane": "Trackpad",
        "Mouse.prefPane": "Mouse",
        "Keyboard.prefPane": "Keyboard",
        "Desktop.prefPane": "Desktop",
        "Dock.prefPane": "Dock",
        "Spotlight.prefPane": "Spotlight",
        "TimeMachine.prefPane": "Time Machine",
        "SoftwareUpdate.prefPane": "Software Update",
    ]

    static func displayName(for url: URL, fallback: String) -> String {
        let bundled = bundleName(url)
        let stem = url.deletingPathExtension().lastPathComponent
        if let bundled, bundled.caseInsensitiveCompare(stem) != .orderedSame {
            return bundled
        }
        if let known = mapped[url.lastPathComponent] { return known }
        return bundled ?? fallback
    }

    private static func bundleName(_ url: URL) -> String? {
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            if let name = plist[key] as? String {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }
}

/// Where the file search looks. `SpotlightSearch` runs the queries.
enum FileSearch {
    static func scopeRoots(_ preferences: Preferences) -> [String] {
        // Read mount points from the kernel's cache. Calling stat or statfs on a
        // network mount (an NFS share, ~/OrbStack) can block until the server
        // answers, so those are ruled out before anything touches them.
        let remote = networkMounts()
        var roots: [String] = []
        if preferences.scopeApplications {
            roots.append("/Applications")
            roots.append("/System/Applications")
        }
        if preferences.scopeHome {
            let configured = preferences.fileCustomHomeFolder.trimmingCharacters(in: .whitespaces)
            let homePath = (configured.isEmpty || configured == "~")
                ? NSHomeDirectory()
                : (configured as NSString).expandingTildeInPath
            // Names only: asking for resource values would stat every entry.
            if !isUnder(homePath, remote), let names = try? FileManager.default.contentsOfDirectory(atPath: homePath) {
                for name in names.sorted() where !name.hasPrefix(".") {
                    let path = (homePath as NSString).appendingPathComponent(name)
                    if shouldIndex(path, remote: remote) { roots.append(path) }
                }
            }
        }
        for path in preferences.scopePaths {
            let expanded = (path as NSString).expandingTildeInPath
            if shouldIndex(expanded, remote: remote) { roots.append(expanded) }
        }
        var seen = Set<String>()
        return roots.filter { seen.insert($0).inserted }
    }

    /// Home music libraries and network mounts each raise a privacy prompt.
    private static func shouldIndex(_ path: String, remote: [String]) -> Bool {
        if isUnder(path, remote) { return false }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return false }
        let name = (path as NSString).lastPathComponent
        if name == "Library" || name == "Music" { return false }
        var info = statfs()
        guard statfs(path, &info) == 0 else { return false }
        return info.f_flags & UInt32(MNT_LOCAL) != 0
    }

    private static func isUnder(_ path: String, _ mounts: [String]) -> Bool {
        mounts.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    /// Mount points of file systems that are not local, without contacting them.
    private static func networkMounts() -> [String] {
        var mounts: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&mounts, MNT_NOWAIT)
        guard count > 0, let mounts else { return [] }
        var paths: [String] = []
        for index in 0..<Int(count) {
            var info = mounts[index]
            guard info.f_flags & UInt32(MNT_LOCAL) == 0 else { continue }
            let path = withUnsafeBytes(of: &info.f_mntonname) { raw in
                String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
            }
            if path.count > 1 { paths.append(path) }
        }
        return paths
    }
}

enum BookmarkIndex {
    static func load(preferences: Preferences) -> [LinkRecord] {
        var links: [LinkRecord] = []
        if preferences.chromeBookmarks { links.append(contentsOf: chromeBookmarks()) }
        if preferences.safariBookmarks { links.append(contentsOf: safariBookmarks()) }
        return links
    }

    static func history() -> [LinkRecord] {
        chromeHistory() + safariHistory()
    }

    private static func chromeBookmarks() -> [LinkRecord] {
        let root = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support/Google/Chrome")
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: root) else { return [] }
        var links: [LinkRecord] = []
        for dir in dirs {
            let url = URL(fileURLWithPath: root).appendingPathComponent(dir).appendingPathComponent("Bookmarks")
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let roots = json["roots"] as? [String: Any]
            else { continue }
            for (_, value) in roots {
                walkChrome(value, into: &links, source: "Chrome")
            }
        }
        return links
    }

    private static func walkChrome(_ node: Any, into links: inout [LinkRecord], source: String) {
        guard let dict = node as? [String: Any] else { return }
        if let type = dict["type"] as? String, type == "url", let url = dict["url"] as? String {
            let title = dict["name"] as? String ?? url
            links.append(LinkRecord(id: "chrome:\(url)", title: title, url: url, source: source))
        }
        if let children = dict["children"] as? [Any] {
            for child in children { walkChrome(child, into: &links, source: source) }
        }
    }

    private static func safariBookmarks() -> [LinkRecord] {
        let url = URL(fileURLWithPath: (NSHomeDirectory() as NSString).appendingPathComponent("Library/Safari/Bookmarks.plist"))
        guard let data = try? Data(contentsOf: url),
              let root = try? PropertyListSerialization.propertyList(from: data, format: nil)
        else { return [] }
        var links: [LinkRecord] = []
        walkSafari(root, into: &links)
        return links
    }

    private static func walkSafari(_ node: Any, into links: inout [LinkRecord]) {
        guard let dict = node as? [String: Any] else { return }
        if let url = dict["URLString"] as? String {
            let title = (dict["URIDictionary"] as? [String: Any])?["title"] as? String ?? dict["Title"] as? String ?? url
            links.append(LinkRecord(id: "safari:\(url)", title: title, url: url, source: "Safari"))
        }
        if let children = dict["Children"] as? [Any] {
            for child in children { walkSafari(child, into: &links) }
        }
    }

    private static func chromeHistory() -> [LinkRecord] {
        let root = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support/Google/Chrome")
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: root) else { return [] }
        var links: [LinkRecord] = []
        for dir in dirs.prefix(6) {
            let db = URL(fileURLWithPath: root).appendingPathComponent(dir).appendingPathComponent("History")
            links.append(contentsOf: readSQLite(db, sql: "select title, url from urls order by last_visit_time desc limit 150;", source: "Chrome History"))
        }
        return links
    }

    private static func safariHistory() -> [LinkRecord] {
        let db = URL(fileURLWithPath: (NSHomeDirectory() as NSString).appendingPathComponent("Library/Safari/History.db"))
        let sql = "select history_visits.title, history_items.url from history_items join history_visits on history_visits.history_item = history_items.id order by history_visits.visit_time desc limit 150;"
        return readSQLite(db, sql: sql, source: "Safari History")
    }

    private static func readSQLite(_ database: URL, sql: String, source: String) -> [LinkRecord] {
        guard FileManager.default.fileExists(atPath: database.path) else { return [] }
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
        guard (try? FileManager.default.copyItem(at: database, to: copy)) != nil else { return [] }
        defer { try? FileManager.default.removeItem(at: copy) }
        let text = Shell.run("/usr/bin/sqlite3", ["-separator", "\t", copy.path, sql], timeout: 3)
        return text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            let title = String(parts[0])
            let url = String(parts[1])
            guard url.hasPrefix("http") else { return nil }
            return LinkRecord(id: "\(source):\(url)", title: title, url: url, source: source)
        }
    }
}

enum ChromeProfiles {
    static func load() -> [ProfileInfo] {
        let url = URL(fileURLWithPath: (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support/Google/Chrome/Local State"))
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let cache = profile["info_cache"] as? [String: Any]
        else { return [] }
        return cache.compactMap { key, value in
            let name = (value as? [String: Any])?["name"] as? String ?? key
            return ProfileInfo(id: key, name: name, directory: key)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

enum WindowList {
    static func fetch() -> [WindowInfo] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        var rows: [WindowInfo] = []
        var seen = Set<String>()
        for item in info {
            let layer = item[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { continue }
            let owner = item[kCGWindowOwnerName as String] as? String ?? ""
            if owner.isEmpty || owner == "Window Server" || owner == "Jfred" { continue }
            let title = item[kCGWindowName as String] as? String ?? ""
            let pid = item[kCGWindowOwnerPID as String] as? Int32 ?? Int32(item[kCGWindowOwnerPID as String] as? Int ?? 0)
            let number = item[kCGWindowNumber as String] as? Int ?? 0
            let key = "\(owner)\n\(title)"
            if !seen.insert(key).inserted { continue }
            rows.append(WindowInfo(id: "\(number)", title: title, owner: owner, pid: pid))
        }
        return rows
    }
}

enum ProcessList {
    static func fetch() -> [ProcInfo] {
        var rows: [ProcInfo] = []
        var seen = Set<Int32>()
        for app in NSWorkspace.shared.runningApplications {
            let pid = app.processIdentifier
            guard seen.insert(pid).inserted, let name = app.localizedName, !name.isEmpty else { continue }
            rows.append(ProcInfo(pid: pid, name: name))
        }
        let text = Shell.run("/bin/ps", ["-ax", "-o", "pid=,comm="], timeout: 2)
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let pid = Int32(parts[0]), pid > 100, seen.insert(pid).inserted else { continue }
            let name = URL(fileURLWithPath: String(parts[1])).lastPathComponent
            rows.append(ProcInfo(pid: pid, name: name))
        }
        return rows
    }
}

enum BrowserTabs {
    static func fetch() -> [LinkRecord] {
        let chrome = Shell.osascript("""
        if application "Google Chrome" is running then
          tell application "Google Chrome"
            set output to ""
            repeat with w in windows
              repeat with t in tabs of w
                set output to output & (title of t) & tab & (URL of t) & linefeed
              end repeat
            end repeat
            return output
          end tell
        end if
        """, timeout: 3)
        let safari = Shell.osascript("""
        if application "Safari" is running then
          tell application "Safari"
            set output to ""
            repeat with w in windows
              repeat with t in tabs of w
                set output to output & (name of t) & tab & (URL of t) & linefeed
              end repeat
            end repeat
            return output
          end tell
        end if
        """, timeout: 3)
        return parse(chrome, source: "Chrome Tab") + parse(safari, source: "Safari Tab")
    }

    private static func parse(_ text: String, source: String) -> [LinkRecord] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            let title = String(parts[0])
            let url = String(parts[1])
            return LinkRecord(id: "\(source):\(url)", title: title, url: url, source: source)
        }
    }
}

enum DictionaryLookup {
    static func define(_ word: String) -> String? {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let range = CFRange(location: 0, length: (trimmed as NSString).length)
        guard let value = DCSCopyTextDefinition(nil, trimmed as CFString, range)?.takeRetainedValue() else { return nil }
        let text = value as String
        return text.isEmpty ? nil : text
    }
}

enum OnePassword {
    static func items() -> [AppRecord] {
        let binaries = ["/opt/homebrew/bin/op", "/usr/local/bin/op", "/usr/bin/op"]
        guard let binary = binaries.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return [] }
        let text = Shell.run(binary, ["item", "list", "--format=json"], timeout: 12)
        guard let data = text.data(using: .utf8),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return rows.compactMap { row in
            guard let id = row["id"] as? String, let title = row["title"] as? String else { return nil }
            return AppRecord(id: id, name: title, path: id)
        }
    }
}

enum Accessibility {
    static func prompt() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func trusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func selectedText() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String,
              !text.isEmpty else { return nil }
        return text
    }

    static func finderSelection() -> [String] {
        let text = Shell.osascript("""
        tell application "Finder"
          try
            set sel to selection as alias list
          on error
            return ""
          end try
          set out to ""
          repeat with f in sel
            set out to out & POSIX path of f & linefeed
          end repeat
          return out
        end tell
        """)
        return text.split(separator: "\n").map(String.init).filter { $0.hasPrefix("/") }
    }
}

/// Post one key press. Returns false when the events could not be created.
@discardableResult
func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) -> Bool {
    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
          let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return false }
    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
    return true
}

/// Virtual key codes Jfred posts.
enum KeyCode {
    static let v: CGKeyCode = 9
    static let delete: CGKeyCode = 51
    static let leftArrow: CGKeyCode = 123
}

final class SnippetExpander: @unchecked Sendable {
    static let shared = SnippetExpander()
    private let lock = NSLock()
    private var enabled = false
    private var suspended = false
    private var snippets: [String: String] = [:]
    private var buffer = ""
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var ignore = 0

    private var wordBased = true
    private var playSound = true
    private var restoreClipboard = true

    func update(enabled: Bool, snippets: [Snippet], wordBased: Bool = true, playSound: Bool = true, restoreClipboard: Bool = true) {
        lock.lock()
        self.enabled = enabled
        self.wordBased = wordBased
        self.playSound = playSound
        self.restoreClipboard = restoreClipboard
        self.snippets = Dictionary(snippets.filter(\.autoExpand).map { ($0.keyword, $0.text) }, uniquingKeysWith: { first, _ in first })
        lock.unlock()
        if enabled { install() }
    }

    func setSuspended(_ value: Bool) {
        lock.lock()
        suspended = value
        if value { buffer = "" }
        lock.unlock()
    }

    private func install() {
        lock.lock()
        let exists = tap != nil
        lock.unlock()
        if exists { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                SnippetExpander.shared.reenableTap()
                return Unmanaged.passUnretained(event)
            }
            SnippetExpander.shared.handle(event)
            return Unmanaged.passUnretained(event)
        }, userInfo: nil) else { return }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        lock.lock()
        tap = created
        self.source = source
        lock.unlock()
        // A .defaultTap holds every keystroke in every app until the callback
        // returns. Serve it from its own run loop so a busy main thread (a
        // synchronous osascript, a state save, a slow search) cannot stall typing
        // system-wide or get the tap disabled by timeout.
        let thread = Thread { [self] in
            self.runTapLoop()
        }
        thread.name = "Jfred snippet expander tap"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// Body of the tap thread. The source stays attached for the life of the app,
    /// so `CFRunLoopRun` does not return.
    private func runTapLoop() {
        lock.lock()
        let tap = self.tap
        let source = self.source
        lock.unlock()
        guard let tap, let source else { return }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        CFRunLoopRun()
    }

    /// Called on the tap thread when macOS disables the tap.
    private func reenableTap() {
        lock.lock()
        let tap = self.tap
        lock.unlock()
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    /// Runs on the tap thread. Keep it non-blocking: read state under the lock and
    /// hand any expansion to the main queue.
    private func handle(_ event: CGEvent) {
        lock.lock()
        if ignore > 0 {
            ignore -= 1
            lock.unlock()
            return
        }
        let active = enabled && !suspended
        let table = snippets
        let wordBasedMatch = wordBased
        lock.unlock()
        guard active else { return }
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            lock.lock(); buffer = ""; lock.unlock()
            return
        }
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        let text = String(utf16CodeUnits: chars, count: length)
        guard text.count == 1, let character = text.first else {
            lock.lock(); buffer = ""; lock.unlock()
            return
        }
        lock.lock()
        buffer.append(character)
        if buffer.count > 160 { buffer.removeFirst(buffer.count - 160) }
        let current = buffer
        lock.unlock()
        guard character == " " || character == "\t" else { return }
        let stem = String(current.dropLast())
        guard let (keyword, replacement) = Self.match(stem: stem, table: table, wordBased: wordBasedMatch) else { return }
        let deletes = keyword.count + 1
        DispatchQueue.main.async {
            self.expand(replacement, deleting: deletes)
        }
    }

    /// Replace the typed keyword with the snippet. Pasteboard work stays on main.
    @MainActor
    private func expand(_ replacement: String, deleting deletes: Int) {
        // Read before the temporary write below replaces the clipboard.
        let expansion = expandSnippet(replacement, clipboard: TemporaryClipboard.userText())
        lock.lock()
        ignore = 0
        buffer = ""
        let restore = restoreClipboard
        let sound = playSound
        lock.unlock()
        postIgnoringTap(KeyCode.delete, count: deletes)
        let pending = TemporaryClipboard.write(expansion.text, restoring: restore)
        postIgnoringTap(KeyCode.v, flags: .maskCommand)
        postIgnoringTap(KeyCode.leftArrow, count: expansion.cursorOffset)
        if let pending {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                TemporaryClipboard.restore(pending)
            }
        }
        if sound { NSSound(named: "Purr")?.play() }
        AppRuntime.model?.record(category: "expansion")
    }

    /// Post synthetic key presses the tap must not read as typing: the deletes
    /// and ⌘V of an expansion, and the Left Arrows that place a `{cursor}`.
    /// The count is only kept while the tap exists to consume it.
    func postIgnoringTap(_ keyCode: CGKeyCode, flags: CGEventFlags = [], count: Int = 1) {
        guard count > 0 else { return }
        lock.lock()
        let counted = tap != nil
        if counted { ignore += count }
        lock.unlock()
        var failed = 0
        for _ in 0..<count where !postKey(keyCode, flags: flags) { failed += 1 }
        guard counted, failed > 0 else { return }
        lock.lock()
        ignore = max(0, ignore - failed)
        lock.unlock()
    }

    private static func match(stem: String, table: [String: String], wordBased: Bool) -> (String, String)? {
        for key in table.keys.sorted(by: { $0.count > $1.count }) where key.count >= 2 {
            guard let value = table[key] else { continue }
            if stem == key { return (key, value) }
            if stem.hasSuffix(key) {
                if !wordBased { return (key, value) }
                let prefix = stem.dropLast(key.count)
                if prefix.last?.isWhitespace == true { return (key, value) }
            }
        }
        return nil
    }
}

enum SupportPaths {
    static func directory(syncFolder: String) -> URL {
        let url: URL
        if !syncFolder.isEmpty {
            let base = URL(fileURLWithPath: (syncFolder as NSString).expandingTildeInPath, isDirectory: true)
            url = base.appendingPathComponent("JfredLocal", isDirectory: true)
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            url = appSupport.appendingPathComponent("JfredLocal", isDirectory: true)
            adoptPreviousState(into: url)
        }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    private static func adoptPreviousState(into directory: URL) {
        let destination = directory.appendingPathComponent("state.json")
        if FileManager.default.fileExists(atPath: destination.path) { return }
        let legacy = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JlfredLocal/state.json")
        guard FileManager.default.fileExists(atPath: legacy.path) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? FileManager.default.copyItem(at: legacy, to: destination)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    }
}
