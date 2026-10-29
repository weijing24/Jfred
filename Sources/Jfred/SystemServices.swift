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
        return AppRecord(id: path, name: "Finder", path: path)
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
                results.append(AppRecord(id: resolved.path, name: name, path: resolved.path))
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

private final class AppRecordBox: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [AppRecord] = []

    func append(_ rows: [AppRecord]) {
        lock.lock()
        items.append(contentsOf: rows)
        lock.unlock()
    }

    var values: [AppRecord] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }
}

enum FileSearch {
    static func files(query: String, preferences: Preferences) -> [AppRecord] {
        let safe = query.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
        guard safe.count >= 1 else { return [] }
        if FileIndex.shared.isReady {
            return FileIndex.shared.search(query: safe, limit: max(preferences.fileSearchMax, 400))
        }
        return spotlight(query: safe, preferences: preferences)
    }

    private static func spotlight(query: String, preferences: Preferences) -> [AppRecord] {
        let predicate = "kMDItemDisplayName == \"*\(query)*\"c"
        let roots = scopeRoots(preferences)
        let found = AppRecordBox()
        let group = DispatchGroup()
        for root in roots.prefix(8) {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let text = Shell.run("/usr/bin/mdfind", ["-onlyin", root, predicate], timeout: 1.1)
                let rows = text.split(separator: "\n").prefix(15).map { line -> AppRecord in
                    let path = String(line)
                    return AppRecord(id: path, name: FileManager.default.displayName(atPath: path), path: path)
                }
                found.append(rows)
                group.leave()
            }
        }
        _ = group.wait(timeout: .now() + 1.5)
        var seen = Set<String>()
        return found.values.filter { seen.insert($0.path).inserted }.prefix(preferences.fileSearchMax).map { $0 }
    }

    static func scopeRoots(_ preferences: Preferences) -> [String] {
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
            let home = URL(fileURLWithPath: homePath)
            if let items = try? FileManager.default.contentsOfDirectory(at: home, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for url in items where shouldIndex(url.path) {
                    roots.append(url.path)
                }
            }
        }
        for path in preferences.scopePaths {
            let expanded = (path as NSString).expandingTildeInPath
            if shouldIndex(expanded) { roots.append(expanded) }
        }
        return roots
    }

    /// Home music libraries and network mounts each raise a privacy prompt.
    private static func shouldIndex(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return false }
        let name = (path as NSString).lastPathComponent
        if name == "Library" || name == "Music" { return false }
        var info = statfs()
        guard statfs(path, &info) == 0 else { return false }
        return info.f_flags & UInt32(MNT_LOCAL) != 0
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

func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
          let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }
    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
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
                if let tap = SnippetExpander.shared.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            SnippetExpander.shared.handle(event)
            return Unmanaged.passUnretained(event)
        }, userInfo: nil) else { return }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        lock.lock()
        tap = created
        self.source = source
        lock.unlock()
    }

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
        let expanded = expandTokens(replacement)
        let deletes = keyword.count + 1
        DispatchQueue.main.async {
            self.lock.lock()
            self.ignore = deletes
            self.buffer = ""
            self.lock.unlock()
            for _ in 0..<deletes { postKey(51) }
            self.paste(expanded)
            self.lock.lock()
            let sound = self.playSound
            self.lock.unlock()
            if sound { NSSound(named: "Purr")?.play() }
            Task { @MainActor in
                AppRuntime.model?.record(category: "expansion")
            }
        }
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

    private func paste(_ text: String) {
        let board = NSPasteboard.general
        let previous = board.string(forType: .string)
        board.clearContents()
        board.setString(text, forType: .string)
        lock.lock()
        ignore += 1
        lock.unlock()
        postKey(9, flags: .maskCommand)
        lock.lock()
        let restore = restoreClipboard
        lock.unlock()
        guard restore else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            board.clearContents()
            if let previous { board.setString(previous, forType: .string) }
        }
    }
}

final class RemoteReply: @unchecked Sendable {
    var body = "Remote is not ready"
}

final class RemoteServer: @unchecked Sendable {
    private var fd: Int32 = -1
    private var running = false
    private var localOnly = true
    var handle: ((String) -> String)?

    func start(port: UInt16, localOnly: Bool) -> String? {
        stop()
        self.localOnly = localOnly
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else { return "Could not open a socket" }
        var yes: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = localOnly ? inet_addr("127.0.0.1") : INADDR_ANY
        let bound = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        if bound != 0 || listen(socketFD, 8) != 0 {
            close(socketFD)
            return "Port \(port) is not available"
        }
        fd = socketFD
        running = true
        Thread.detachNewThread { [weak self] in
            guard let self else { return }
            while self.running {
                let client = accept(socketFD, nil, nil)
                if client < 0 { break }
                self.serve(client)
                close(client)
            }
        }
        return nil
    }

    func stop() {
        running = false
        if fd >= 0 {
            close(fd)
            fd = -1
        }
    }

    private func serve(_ client: Int32) {
        var buffer = [UInt8](repeating: 0, count: 8192)
        let count = read(client, &buffer, buffer.count)
        guard count > 0, let request = String(bytes: buffer.prefix(count), encoding: .utf8) else { return }
        let lines = request.components(separatedBy: "\r\n")
        let first = lines.first ?? ""
        let parts = first.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            writeResponse(client, status: "405 Method Not Allowed", body: "<p>Method not allowed.</p>", extraHeaders: "Allow: GET\r\n")
            return
        }
        if localOnly {
            let host = lines.first(where: { $0.lowercased().hasPrefix("host:") })?
                .dropFirst(5).trimmingCharacters(in: .whitespaces).lowercased() ?? ""
            let allowed = ["127.0.0.1", "localhost", "[::1]", "::1"]
            guard allowed.contains(where: { host == $0 || host.hasPrefix($0 + ":") }) else {
                writeResponse(client, status: "403 Forbidden", body: "<p>Invalid host.</p>")
                return
            }
        }
        let target = String(parts[1])
        guard target.hasPrefix("/") else {
            writeResponse(client, status: "400 Bad Request", body: "<p>Bad request.</p>")
            return
        }
        let sem = DispatchSemaphore(value: 0)
        let slot = RemoteReply()
        DispatchQueue.main.async {
            slot.body = self.handle?(target) ?? slot.body
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 2)
        writeResponse(client, status: "200 OK", body: slot.body)
    }

    private func writeResponse(_ client: Int32, status: String, body: String, extraHeaders: String = "") {
        let data = Data(body.utf8)
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(data.count)\r
        Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; form-action 'self'\r
        X-Content-Type-Options: nosniff\r
        Referrer-Policy: no-referrer\r
        Connection: close\r
        \(extraHeaders)\r

        """
        var packet = Data(header.utf8)
        packet.append(data)
        packet.withUnsafeBytes { raw in
            _ = write(client, raw.baseAddress, raw.count)
        }
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
