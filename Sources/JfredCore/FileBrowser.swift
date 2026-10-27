import Foundation

public enum FileBrowser {
    public struct Entry: Sendable {
        public var name: String
        public var path: String
        public var isDirectory: Bool
    }

    public static func entries(for raw: String) -> [Entry]? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") || trimmed.hasPrefix("~") else { return nil }
        let expanded = (trimmed as NSString).expandingTildeInPath
        let directory: String
        let prefix: String
        if trimmed.hasSuffix("/") {
            directory = expanded
            prefix = ""
        } else {
            directory = (expanded as NSString).deletingLastPathComponent
            prefix = (expanded as NSString).lastPathComponent
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDir), isDir.boolValue else { return [] }
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        let needle = prefix.lowercased()
        return urls.compactMap { url -> Entry? in
            let name = url.lastPathComponent
            if !needle.isEmpty, !name.lowercased().hasPrefix(needle) { return nil }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            return Entry(name: name, path: url.path, isDirectory: values?.isDirectory == true)
        }
        .sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        .prefix(200)
        .map { $0 }
    }
}

