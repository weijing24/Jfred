import CryptoKit
import Foundation

public enum UpdateChannel: String, Equatable, Sendable {
    case updates
    case prereleases

    public init(preference: String) {
        self = preference == Self.prereleases.rawValue ? .prereleases : .updates
    }
}

public struct UpdateAsset: Equatable, Sendable {
    public var name: String
    public var downloadURL: URL
    public var byteCount: Int64
    public var sha256: String

    public init(name: String, downloadURL: URL, byteCount: Int64, sha256: String) {
        self.name = name
        self.downloadURL = downloadURL
        self.byteCount = byteCount
        self.sha256 = sha256
    }
}

public struct UpdateRelease: Equatable, Sendable {
    public var version: String
    public var tag: String
    public var notes: String
    public var prerelease: Bool
    public var asset: UpdateAsset

    public init(version: String, tag: String, notes: String, prerelease: Bool, asset: UpdateAsset) {
        self.version = version
        self.tag = tag
        self.notes = notes
        self.prerelease = prerelease
        self.asset = asset
    }
}

public struct UpdateCatalog: Equatable, Sendable {
    public var releases: [UpdateRelease]
    public var publishedCount: Int

    public init(releases: [UpdateRelease], publishedCount: Int) {
        self.releases = releases
        self.publishedCount = publishedCount
    }
}

public enum UpdateOffer: Equatable, Sendable {
    case upToDate(version: String, notes: String)
    case available(UpdateRelease)
    case unavailable(String)
}

public enum UpdateFeedError: Error, Equatable {
    case malformed
}

public enum UpdateChecksum {
    public static func sha256Hex(file url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1 << 20)
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func matches(file url: URL, sha256 expected: String) -> Bool {
        guard let actual = try? sha256Hex(file: url) else { return false }
        return actual == expected.lowercased()
    }
}

public enum UpdatePaths {
    public static func isInstallableBundlePath(_ path: String) -> Bool {
        guard path.hasPrefix("/") else { return false }
        guard !path.contains("\n"), !path.contains("\r"), !path.contains("\0") else { return false }
        guard !path.split(separator: "/").contains("..") else { return false }
        guard !path.contains("/AppTranslocation/") else { return false }
        guard !path.hasPrefix("/Volumes/") else { return false }
        return URL(fileURLWithPath: path).lastPathComponent == "Jfred.app"
    }
}

public enum AppVersion {
    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult? {
        guard let left = parts(lhs), let right = parts(rhs) else { return nil }
        let count = max(left.numbers.count, right.numbers.count)
        for index in 0..<count {
            let a = index < left.numbers.count ? left.numbers[index] : 0
            let b = index < right.numbers.count ? right.numbers[index] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        if left.prerelease == right.prerelease { return .orderedSame }
        return left.prerelease ? .orderedAscending : .orderedDescending
    }

    private static func parts(_ raw: String) -> (numbers: [Int], prerelease: Bool)? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.first == "v" || text.first == "V" { text.removeFirst() }
        let pieces = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let core = pieces.first, !core.isEmpty else { return nil }
        var numbers: [Int] = []
        for part in core.split(separator: ".") {
            guard !part.isEmpty, part.allSatisfy(\.isNumber) else { return nil }
            if part.count > 1, part.first == "0" { return nil }
            guard let value = Int(part), value >= 0, value < 1_000_000 else { return nil }
            numbers.append(value)
        }
        guard !numbers.isEmpty else { return nil }
        return (numbers, pieces.count > 1)
    }
}

public enum AppUpdateFeed {
    public static let owner = "weijing24"
    public static let repo = "Jfred"
    public static let bundleIdentifier = "dev.jim.jfred.local"
    public static let maxFeedBytes = 1_000_000
    public static let maxAssetBytes: Int64 = 80 * 1024 * 1024
    public static let notesLimit = 12_000

    public static var currentArchitecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }

    public static func releasesURL() -> URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases?per_page=30")!
    }

    public static func assetName(version: String, architecture: String) -> String {
        "Jfred-\(version)-\(architecture).dmg"
    }

    public static func isAllowedAPIHost(_ host: String) -> Bool {
        host.lowercased() == "api.github.com"
    }

    public static func isAllowedAssetHost(_ host: String) -> Bool {
        switch host.lowercased() {
        case "github.com",
             "release-assets.githubusercontent.com",
             "objects.githubusercontent.com",
             "github-releases.githubusercontent.com":
            return true
        default:
            return false
        }
    }

    public static func isOfficialAssetURL(_ url: URL, version: String, architecture: String) -> Bool {
        guard url.scheme == "https", url.port == nil else { return false }
        guard url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return false }
        guard url.host?.lowercased() == "github.com" else { return false }
        guard version.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil else { return false }
        guard architecture == "arm64" || architecture == "x86_64" else { return false }
        let expected = "/\(owner)/\(repo)/releases/download/v\(version)/\(assetName(version: version, architecture: architecture))"
        return url.path == expected
    }

    public static func version(fromTag tag: String) -> String? {
        var text = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.first == "v" || text.first == "V" { text.removeFirst() }
        guard text.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil else { return nil }
        return text
    }

    public static func parse(_ data: Data, architecture: String) throws -> UpdateCatalog {
        guard data.count <= maxFeedBytes else { throw UpdateFeedError.malformed }
        let payloads: [ReleasePayload]
        do {
            payloads = try JSONDecoder().decode([ReleasePayload].self, from: data)
        } catch {
            throw UpdateFeedError.malformed
        }
        var releases: [UpdateRelease] = []
        var publishedCount = 0
        for payload in payloads.prefix(30) {
            guard payload.draft != true else { continue }
            guard let tag = payload.tagName, let version = version(fromTag: tag) else { continue }
            publishedCount += 1
            guard let asset = payload.assets?.compactMap({ accepted($0, version: version, architecture: architecture) }).first else { continue }
            releases.append(UpdateRelease(
                version: version,
                tag: tag,
                notes: notes(payload.body),
                prerelease: payload.prerelease ?? false,
                asset: asset
            ))
        }
        return UpdateCatalog(releases: releases, publishedCount: publishedCount)
    }

    public static func offer(in catalog: UpdateCatalog, channel: UpdateChannel, current: String) -> UpdateOffer {
        let eligible = catalog.releases.filter { channel == .prereleases || !$0.prerelease }
        guard let newest = eligible.max(by: { AppVersion.compare($0.version, $1.version) == .orderedAscending }) else {
            if catalog.publishedCount == 0 {
                return .unavailable("No release has been published yet.")
            }
            if catalog.releases.isEmpty {
                return .unavailable("No build for this Mac is published.")
            }
            return .unavailable("No stable release is published yet.")
        }
        let order = AppVersion.compare(current, newest.version)
        if order == .orderedSame || order == .orderedDescending {
            let notes = eligible.first { AppVersion.compare($0.version, current) == .orderedSame }?.notes ?? newest.notes
            return .upToDate(version: current, notes: notes)
        }
        return .available(newest)
    }

    private static func accepted(_ asset: AssetPayload, version: String, architecture: String) -> UpdateAsset? {
        let name = assetName(version: version, architecture: architecture)
        guard asset.name == name else { return nil }
        guard let raw = asset.browserDownloadURL, let url = URL(string: raw) else { return nil }
        guard isOfficialAssetURL(url, version: version, architecture: architecture) else { return nil }
        guard let sha = sha256(from: asset.digest) else { return nil }
        let size = asset.size ?? 0
        guard size > 0, size <= maxAssetBytes else { return nil }
        return UpdateAsset(name: name, downloadURL: url, byteCount: size, sha256: sha)
    }

    private static func sha256(from digest: String?) -> String? {
        guard let digest else { return nil }
        let parts = digest.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, parts[0].lowercased() == "sha256" else { return nil }
        let hex = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard hex.count == 64, hex.allSatisfy(\.isHexDigit) else { return nil }
        return hex
    }

    private static func notes(_ body: String?) -> String {
        var text = (body ?? "").replacingOccurrences(of: "\r\n", with: "\n")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > notesLimit else { return text }
        let end = text.index(text.startIndex, offsetBy: notesLimit)
        return String(text[..<end]) + "\n…"
    }
}

private struct ReleasePayload: Decodable {
    var tagName: String?
    var body: String?
    var prerelease: Bool?
    var draft: Bool?
    var assets: [AssetPayload]?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case prerelease
        case draft
        case assets
    }
}

private struct AssetPayload: Decodable {
    var name: String?
    var browserDownloadURL: String?
    var size: Int64?
    var digest: String?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
        case digest
    }
}
