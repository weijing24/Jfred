import Foundation
import JfredCore

enum ExternalKeys {
    static let brand = ["al", "fr", "ed"].joined()
    static func named(_ suffix: String) -> String { brand + suffix }
}

struct ScriptNode: Sendable {
    var uid: String
    var type: String
    var keyword: String
    var withSpace: Bool
    var filterLocally: Bool
    var group: String
    var cwd: String
    var bundleID: String
    var name: String
    var script: String
    var scriptType: Int
    var icon: String
}

struct ImportedWorkflow: Sendable {
    var bundle: String
    var name: String
    var author: String
    var keyword: String
    var enabled: Bool
}

struct ScriptCatalog: Sendable {
    var nodes: [String: ScriptNode] = [:]
    var next: [String: String] = [:]
    var workflows: [ImportedWorkflow] = []

    func hit(in query: String, disabledGroups: Set<String>) -> (node: ScriptNode, argument: String)? {
        let filters = nodes.values.filter { node in
            node.type.contains("scriptfilter") && !node.keyword.isEmpty && !disabledGroups.contains(node.group)
        }
        let pairs = filters.map { ($0.keyword, !$0.withSpace) }
        guard let found = bestKeywordMatch(pairs, in: query) else { return nil }
        guard let node = filters.first(where: { fold($0.keyword) == fold(found.keyword) }) else { return nil }
        return (node, found.argument)
    }
}

enum JfredStore {
    @MainActor
    static func reloadCatalog() -> ScriptCatalog? {
        guard let root = refreshSnapshot() else { return nil }
        return loadCatalog(root: root)
    }

    static func catalog() -> ScriptCatalog {
        let root = preferencesRoot() ?? refreshSnapshot()
        guard let root else { return ScriptCatalog() }
        return loadCatalog(root: root)
    }

    @MainActor
    static func apply(_ model: AppModel) -> ScriptCatalog? {
        guard let root = refreshSnapshot() else {
            model.importNote = "Launcher preferences were not found. The original folder was not changed."
            return nil
        }
        if let hotkey = readHotkey(root: root) {
            model.preferences.hotkey = hotkey
        }
        if let terminal = readTerminal(root: root) {
            model.preferences.terminalApp = terminal
        }
        applyWebSearches(root: root, model: model)
        let imported = readSnippets(root: root)
        if !imported.isEmpty { model.snippets = imported }
        let hideMenu = readBool(plist(at: root.appendingPathComponent("preferences/appearance/options/prefs.plist")), key: "hidemenu")
        model.knowledge["statusItem"] = hideMenu ? "hidden" : "shown"
        let catalog = loadCatalog(root: root)
        syncWorkflows(model, catalog.workflows)
        let keywords = catalog.nodes.values.filter { $0.type.contains("scriptfilter") && !$0.keyword.isEmpty }.count
        model.importNote = "Copied launcher settings into Jfred (\(imported.count) snippets, \(keywords) workflow keywords). Terminal is \(model.preferences.terminalApp). The original folder was not changed."
        return catalog
    }

    @MainActor
    static func syncWorkflows(_ model: AppModel, _ imported: [ImportedWorkflow]) {
        let bundles = Set(imported.map(\.bundle))
        let legacy: Set<String> = ["dev", "epoch", "unit", "kill", "tabs", "profiles", "windows", "ui"]
        model.workflows.removeAll { workflow in
            guard let key = workflow.builtin else { return false }
            if legacy.contains(key) { return true }
            return !bundles.contains(key)
        }
        for item in imported {
            if let index = model.workflows.firstIndex(where: { $0.builtin == item.bundle }) {
                model.workflows[index].name = item.name
                model.workflows[index].author = item.author
                if !item.keyword.isEmpty { model.workflows[index].keyword = item.keyword }
                model.workflows[index].enabled = model.workflows[index].enabled && item.enabled
            } else {
                model.workflows.append(Workflow(
                    id: uuid(in: item.bundle) ?? UUID(),
                    name: item.name,
                    keyword: item.keyword,
                    author: item.author,
                    symbol: "puzzlepiece.extension",
                    tint: tint(for: item.bundle),
                    enabled: item.enabled,
                    builtin: item.bundle
                ))
            }
        }
    }

    private static func tint(for bundle: String) -> String {
        let palette = ["6C5CE7", "0984E3", "00B894", "E17055", "FDCB6E", "8E44AD", "2D3436", "C0392B", "16A085"]
        let sum = bundle.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }

    static func preferencesRoot() -> URL? {
        let url = snapshotURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// Copies the external launcher preferences into Jfred's folder. The source directory is only read by `ditto`.
    static func refreshSnapshot() -> URL? {
        guard let source = launcherSource() else { return nil }
        let destination = snapshotURL()
        let parent = destination.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        let staging = parent.appendingPathComponent("LauncherPreferences.incoming")
        moveAside(staging)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [source.url.path, staging.path]
        do {
            try process.run()
        } catch {
            moveAside(staging)
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: staging.path) else {
            moveAside(staging)
            return nil
        }
        moveAside(destination)
        do {
            try FileManager.default.moveItem(at: staging, to: destination)
        } catch {
            return nil
        }
        let marker: [String: String] = [
            "localhash": source.hash ?? "",
            "source": source.url.path,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: marker, options: [.prettyPrinted]) {
            try? data.write(to: markerURL(), options: .atomic)
        }
        return destination
    }

    private static func snapshotURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Jfred/LauncherPreferences", isDirectory: true)
    }

    private static func markerURL() -> URL {
        snapshotURL().deletingLastPathComponent().appendingPathComponent("launcher-snapshot.json")
    }

    private static func launcherSource() -> (url: URL, hash: String?)? {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleSuffix = "." + ExternalKeys.brand + "preferences"
        guard let directories = try? FileManager.default.contentsOfDirectory(at: support, includingPropertiesForKeys: nil) else { return nil }
        for directory in directories {
            let pointer = directory.appendingPathComponent("prefs.json")
            guard let data = try? Data(contentsOf: pointer),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = object["current"] as? String,
                  object["syncfolders"] != nil,
                  let hash = object["localhash"] as? String else { continue }
            let url = URL(fileURLWithPath: (current as NSString).expandingTildeInPath, isDirectory: true)
            guard url.lastPathComponent.hasSuffix(bundleSuffix) else { continue }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
            let snapshot = snapshotURL().standardizedFileURL.path
            if url.standardizedFileURL.path == snapshot { continue }
            return (url, hash)
        }
        return nil
    }

    private static func moveAside(_ url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return }
        let trash = URL(fileURLWithPath: "/tmp/grok", isDirectory: true)
        try? FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = trash.appendingPathComponent("\(url.lastPathComponent).\(stamp).\(UUID().uuidString.prefix(8))")
        try? FileManager.default.moveItem(at: url, to: destination)
    }

    private static func loadCatalog(root: URL) -> ScriptCatalog {
        var catalog = ScriptCatalog()
        let workflows = root.appendingPathComponent("workflows")
        guard let directories = try? FileManager.default.contentsOfDirectory(at: workflows, includingPropertiesForKeys: nil) else {
            return catalog
        }
        for directory in directories {
            guard let info = plist(at: directory.appendingPathComponent("info.plist")) else { continue }
            let enabled = !readBool(info, key: "disabled")
            let bundle = info["bundleid"] as? String ?? directory.lastPathComponent
            let group = bundle
            let name = info["name"] as? String ?? bundle
            let author = info["createdby"] as? String ?? "Imported"
            let objects = info["objects"] as? [[String: Any]] ?? []
            var firstKeyword = ""
            for object in objects {
                guard let uid = object["uid"] as? String else { continue }
                let type = object["type"] as? String ?? ""
                let config = object["config"] as? [String: Any] ?? [:]
                let keyword = config["keyword"] as? String ?? ""
                if firstKeyword.isEmpty, type.contains("scriptfilter"), !keyword.isEmpty { firstKeyword = keyword }
                catalog.nodes[uid] = ScriptNode(
                    uid: uid,
                    type: type,
                    keyword: keyword,
                    withSpace: (config["withspace"] as? Bool) ?? true,
                    filterLocally: (config[ExternalKeys.named("filtersresults")] as? Bool) ?? false,
                    group: group,
                    cwd: directory.path,
                    bundleID: bundle,
                    name: name,
                    script: config["script"] as? String ?? "",
                    scriptType: int(config["type"]) ?? 0,
                    icon: "symbol:puzzlepiece.extension"
                )
            }
            let connections = info["connections"] as? [String: Any] ?? [:]
            for (source, value) in connections {
                let links = value as? [[String: Any]] ?? []
                let preferred = links.first { link in
                    if link["modifiers"] == nil { return true }
                    return int(link["modifiers"]) == 0
                } ?? links.first
                if let destination = preferred?["destinationuid"] as? String {
                    catalog.next[source] = destination
                }
            }
            catalog.workflows.append(ImportedWorkflow(bundle: bundle, name: name, author: author, keyword: firstKeyword, enabled: enabled))
        }
        return catalog
    }

    private static func readHotkey(root: URL) -> Hotkey? {
        guard let hash = rememberedHash(), !hash.isEmpty,
              let info = plist(at: root.appendingPathComponent("preferences/local/\(hash)/hotkey/prefs.plist")),
              let hotkey = info["default"] as? [String: Any],
              let key = int(hotkey["key"]),
              let modifiers = int(hotkey["mod"]) else { return nil }
        return Hotkey(keyCode: UInt16(key), modifiers: UInt(modifiers))
    }

    private static func rememberedHash() -> String? {
        guard let data = try? Data(contentsOf: markerURL()),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hash = object["localhash"] as? String else { return nil }
        return hash
    }

    private static func readTerminal(root: URL) -> String? {
        guard let info = plist(at: root.appendingPathComponent("preferences/features/terminal/prefs.plist")),
              let application = int(info["application"]) else { return nil }
        switch application {
        case 0: return "Terminal"
        case 1: return "iTerm"
        default: return nil
        }
    }

    @MainActor
    private static func applyWebSearches(root: URL, model: AppModel) {
        let folder = root.appendingPathComponent("preferences/features/websearch")
        guard let names = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        var disabled = Set<String>()
        for name in names where name.hasDirectoryPath {
            let info = plist(at: name.appendingPathComponent("prefs.plist"))
            if readBool(info, key: "disabled") { disabled.insert(name.lastPathComponent) }
        }
        for index in model.preferences.webSearches.indices {
            let id = model.preferences.webSearches[index].id
            let turnedOff = id == "github" || disabled.contains(id) || (id == "maps" && (disabled.contains("maps") || disabled.contains("applemaps")))
            if id == "google" || !turnedOff { continue }
            model.preferences.webSearches[index].enabled = false
            model.preferences.webSearches[index].fallback = false
        }
    }

    private static func readSnippets(root: URL) -> [Snippet] {
        let folder = root.appendingPathComponent("snippets")
        guard let collections = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return []
        }
        var snippets: [Snippet] = []
        for collection in collections where collection.hasDirectoryPath {
            let info = plist(at: collection.appendingPathComponent("info.plist")) ?? [:]
            let prefix = info["snippetkeywordprefix"] as? String ?? ""
            let suffix = info["snippetkeywordsuffix"] as? String ?? ""
            guard let files = try? FileManager.default.contentsOfDirectory(at: collection, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.pathExtension == "json" {
                guard let data = try? Data(contentsOf: file),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let body = object[ExternalKeys.named("snippet")] as? [String: Any],
                      let name = body["name"] as? String,
                      let text = body["snippet"] as? String else { continue }
                let middle = (body["keyword"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let expands = !middle.isEmpty
                let keyword = expands ? prefix + middle + suffix : name
                let id = uuid(in: file.lastPathComponent) ?? UUID()
                snippets.append(Snippet(id: id, name: name, keyword: keyword, text: text, autoExpand: expands))
            }
        }
        return snippets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func uuid(in name: String) -> UUID? {
        guard let open = name.lastIndex(of: "["), let close = name.lastIndex(of: "]"), open < close else { return nil }
        let value = name[name.index(after: open)..<close]
        return UUID(uuidString: String(value))
    }

    private static func plist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else { return nil }
        return object as? [String: Any]
    }

    private static func readBool(_ info: [String: Any]?, key: String) -> Bool {
        guard let info else { return false }
        if let value = info[key] as? Bool { return value }
        if let value = info[key] as? NSNumber { return value.boolValue }
        return false
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }
}

enum ScriptRunner {
    static func results(catalog: ScriptCatalog, node: ScriptNode, argument: String) -> [SearchResult]? {
        let scriptArgument = node.filterLocally ? "" : (node.keyword == "uuid" && argument.isEmpty ? "1" : argument)
        guard let output = execute(node, argument: scriptArgument),
              let items = ScriptJSON.items(in: output) else { return nil }
        let visible = node.filterLocally && !argument.isEmpty ? items.filter { matches($0, query: argument) } : items
        return visible.enumerated().map { index, item in
            row(catalog: catalog, node: node, item: item, index: index)
        }
    }

    static func results(catalog: ScriptCatalog, uid: String, argument: String) -> [SearchResult]? {
        guard let node = catalog.nodes[uid] else { return nil }
        return results(catalog: catalog, node: node, argument: argument)
    }

    static func runAction(catalog: ScriptCatalog, uid: String, argument: String) {
        guard let node = catalog.nodes[uid] else { return }
        _ = execute(node, argument: argument)
    }

    private static func row(catalog: ScriptCatalog, node: ScriptNode, item: ScriptJSON.Item, index: Int) -> SearchResult {
        let title = item.title.isEmpty ? node.keyword : item.title
        if !item.valid {
            return SearchResult(id: "run:\(node.uid):\(index)", title: title, subtitle: item.subtitle, icon: node.icon, kind: "text", payload: "", category: "action", score: 2)
        }
        switch action(catalog: catalog, from: node.uid, arg: item.arg) {
        case .copy(let text):
            if text.hasPrefix("/"), FileManager.default.fileExists(atPath: text) {
                return SearchResult(id: "run:\(node.uid):\(index)", title: title, subtitle: item.subtitle, icon: "file:\(text)", kind: "file", payload: text, category: "action", score: 2)
            }
            return SearchResult(id: "run:\(node.uid):\(index)", title: title, subtitle: item.subtitle, icon: node.icon, kind: "copy", payload: text, category: "action", score: 2)
        case .open(let url):
            return SearchResult(id: "run:\(node.uid):\(index)", title: title, subtitle: item.subtitle.isEmpty ? url : item.subtitle, icon: "symbol:globe", kind: "url", payload: url, category: "navigation", score: 2)
        case .script(let uid, let arg):
            return SearchResult(id: "run:\(node.uid):\(index)", title: title, subtitle: item.subtitle, icon: node.icon, kind: "external", payload: uid + "\n" + arg, category: "action", score: 2)
        case .chain(let uid, let arg):
            return SearchResult(id: "run:\(node.uid):\(index)", title: title, subtitle: item.subtitle, icon: node.icon, kind: "externalchain", payload: uid + "\n" + arg, category: "action", score: 2)
        }
    }

    private enum Action {
        case copy(String)
        case open(String)
        case script(String, String)
        case chain(String, String)
    }

    private static func action(catalog: ScriptCatalog, from uid: String, arg: String) -> Action {
        guard var current = catalog.next[uid] else {
            if arg.hasPrefix("http://") || arg.hasPrefix("https://") { return .open(arg) }
            return .copy(arg)
        }
        for _ in 0..<8 {
            guard let node = catalog.nodes[current] else { return .copy(arg) }
            if node.type.contains("action.script") { return .script(node.uid, arg) }
            if node.type.contains("openurl") { return .open(arg) }
            if node.type.contains("scriptfilter") { return .chain(node.uid, arg) }
            if node.type.contains("clipboard") { return .copy(arg) }
            guard let destination = catalog.next[current] else { return .copy(arg) }
            current = destination
        }
        return .copy(arg)
    }

    private static func matches(_ item: ScriptJSON.Item, query: String) -> Bool {
        let haystack = fold(item.title + " " + item.subtitle + " " + item.arg)
        return haystack.contains(fold(query))
    }

    private static func execute(_ node: ScriptNode, argument: String) -> String? {
        guard !node.script.isEmpty else { return nil }
        let cache = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/JfredLocal/Workflows/\(node.bundleID)")
        let data = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/JfredLocal/Workflow Data/\(node.bundleID)")
        try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        var environment = ProcessInfo.processInfo.environment
        let path = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
        environment["PATH"] = path
        environment[ExternalKeys.named("_workflow_bundleid")] = node.bundleID
        environment[ExternalKeys.named("_workflow_cache")] = cache.path
        environment[ExternalKeys.named("_workflow_data")] = data.path
        environment[ExternalKeys.named("_workflow_name")] = node.name
        environment[ExternalKeys.named("_workflow_version")] = "1"
        let output = Shell.run(
            interpreter(node.scriptType),
            ["-c", node.script, "jfred", argument],
            timeout: 12,
            directory: URL(fileURLWithPath: node.cwd, isDirectory: true),
            environment: environment
        )
        return output
    }

    private static func interpreter(_ type: Int) -> String {
        switch type {
        case 0: return "/bin/bash"
        case 1: return "/usr/bin/php"
        case 2: return "/usr/bin/ruby"
        case 3: return "/usr/bin/python3"
        case 4: return "/usr/bin/perl"
        case 5: return "/bin/zsh"
        case 6: return "/usr/bin/osascript"
        default: return "/bin/zsh"
        }
    }
}
