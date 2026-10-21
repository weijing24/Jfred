import AppKit
import JfredCore
import Foundation
import ServiceManagement

enum AppRuntime {
    @MainActor static var model: AppModel?
    @MainActor static var openPreferences: (() -> Void)?
}

struct DiskState: Codable {
    var preferences: Preferences
    var workflows: [Workflow]
    var snippets: [Snippet]
    var clips: [ClipItem]
    var usage: [UsageEvent]
    var knowledge: [String: String]
    var selections: [String: SelectionStat]

    init(preferences: Preferences, workflows: [Workflow], snippets: [Snippet], clips: [ClipItem], usage: [UsageEvent], knowledge: [String: String], selections: [String: SelectionStat]) {
        self.preferences = preferences
        self.workflows = workflows
        self.snippets = snippets
        self.clips = clips
        self.usage = usage
        self.knowledge = knowledge
        self.selections = selections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferences = try container.decode(Preferences.self, forKey: .preferences)
        workflows = try container.decode([Workflow].self, forKey: .workflows)
        snippets = try container.decode([Snippet].self, forKey: .snippets)
        clips = try container.decode([ClipItem].self, forKey: .clips)
        usage = try container.decode([UsageEvent].self, forKey: .usage)
        knowledge = try container.decode([String: String].self, forKey: .knowledge)
        selections = try container.decodeIfPresent([String: SelectionStat].self, forKey: .selections) ?? [:]
    }
}

enum Seed {
    static func workflows() -> [Workflow] {
        [
            Workflow(name: "DevToys", keyword: "encode", author: "Built in", symbol: "hammer.fill", tint: "6C5CE7", builtin: "dev"),
            Workflow(name: "Epoch Converter", keyword: "ts", author: "Built in", symbol: "clock.fill", tint: "0984E3", builtin: "epoch"),
            Workflow(name: "Window Switcher", keyword: "win", author: "Built in", symbol: "macwindow", tint: "E17055", enabled: false, builtin: "windows", hotkey: Hotkey(keyCode: 48, modifiers: Hotkey.option)),
            Workflow(name: "Kill Process", keyword: "kill", author: "Built in", symbol: "xmark.octagon.fill", tint: "2D3436", builtin: "kill"),
            Workflow(name: "Search Browser Tabs and History", keyword: "tabnhistory", author: "Built in", symbol: "globe", tint: "00B894", builtin: "tabs"),
            Workflow(name: "Switch Chrome Profiles", keyword: "cp", author: "Built in", symbol: "person.2.fill", tint: "6C5CE7", builtin: "profiles"),
            Workflow(name: "uicli", keyword: "uicli login", author: "Built in", symbol: "cursorarrow.click.2", tint: "0984E3", builtin: "ui"),
            Workflow(name: "Unit Converter", keyword: "conv", author: "Built in", symbol: "ruler.fill", tint: "FDCB6E", builtin: "unit"),
        ]
    }

    static func snippets() -> [Snippet] {
        [
            Snippet(name: "Date", keyword: ";date", text: "{date}"),
            Snippet(name: "Time", keyword: ";time", text: "{time}"),
            Snippet(name: "ISO timestamp", keyword: ";iso", text: "{iso}"),
        ]
    }
}

@MainActor
@Observable
final class AppModel {
    var preferences = Preferences()
    var workflows: [Workflow] = []
    var snippets: [Snippet] = []
    var clips: [ClipItem] = []
    var usage: [UsageEvent] = []
    var knowledge: [String: String] = [:]
    var selections: [String: SelectionStat] = [:]
    var apps: [AppRecord] = []
    var links: [LinkRecord] = []
    var contacts: [ContactRecord] = []
    var opItems: [AppRecord] = []

    var query = ""
    var results: [SearchResult] = []
    var selection = 0
    var launcherVisible = false
    var fileBuffer: [SearchResult] = []
    var hotkeyWarning = ""
    var hotkeyFieldFocused = false
    var remoteWarning = ""
    var debugLine = "Debugger Stopped"
    var prefsQuery = ""
    var section: PrefSection = .general
    var feature: FeatureID = .defaultResults
    var remoteCategory: RemoteCategory = .system
    var selectedWorkflow: UUID?
    var focusToken = 0
    var featureSheet: FeatureSheet?
    var selectedScopePath: String?
    var workflowFilter = ""
    var editingWorkflowID: UUID?
    var workflowSnapshot: Workflow?
    var workflowIsNew = false
    var showTemplates = false
    var showGallery = false
    var scriptCatalog = ScriptCatalog()
    var importNote = ""
    var showStatusItem: Bool {
        get { knowledge["statusItem"] != "hidden" }
        set {
            knowledge["statusItem"] = newValue ? "shown" : "hidden"
            refreshStatusItem()
            scheduleSave()
        }
    }

    private var generation = 0
    private var historyCursor: Int?
    private var fromHistory = false
    private var clipChange = 0
    private var previousApp: NSRunningApplication?
    private var saveWork: DispatchWorkItem?
    var launcher: LauncherController?
    let remote = RemoteServer()
    private var didStart = false
    private var suppressPrompts: Bool {
        ProcessInfo.processInfo.environment["JLFRED_LOCAL_NO_PROMPTS"] == "1"
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        load()
        if selectedWorkflow == nil { selectedWorkflow = workflows.first?.id }
        launcher = LauncherController(model: self)
        launcher?.install()
        refreshStatusItem()
        applyHotkeys()
        if !suppressPrompts {
            applyLoginItem()
            applyExpander()
        }
        applyRemote()
        reindex()
        reloadLinks()
        if preferences.onePasswordEnabled { reloadOnePassword() }
        syncActivationPolicy()
        IndexWatch.shared.start(preferences: preferences) { [weak self] in
            self?.reindex()
        }
        clipChange = NSPasteboard.general.changeCount
        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollClipboard() }
        }
    }

    func scheduleSearch() {
        if fromHistory {
            fromHistory = false
        } else {
            historyCursor = nil
        }
        generation += 1
        let token = generation
        let raw = query
        let catalog = scriptCatalog
        let disabledGroups = Set(workflows.compactMap { workflow -> String? in
            guard let builtin = workflow.builtin, !workflow.enabled else { return nil }
            return builtin
        })
        let base = makeContext(files: [], windows: [], processes: [], tabs: [], profiles: [], definition: nil, forced: nil)
        Task {
            var forced: [SearchResult]?
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let useCatalog = !raw.hasPrefix(" ") && !trimmed.hasPrefix(">")
            if useCatalog, let hit = catalog.hit(in: trimmed, disabledGroups: disabledGroups) {
                let ran = await Task.detached {
                    if hit.node.keyword.hasPrefix("gh ") {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                    }
                    return ScriptRunner.results(catalog: catalog, node: hit.node, argument: hit.argument)
                }.value
                if let ran {
                    forced = ran.isEmpty
                        ? [SearchResult(id: "run:empty", title: "No matches", subtitle: hit.node.keyword, icon: hit.node.icon, kind: "text", payload: "", category: "action", score: 1)]
                        : ran
                }
            }
            var context = base
            if self.workflowHit("kill", trimmed) {
                let processes = await Task.detached { ProcessList.fetch() }.value
                context.processes = processes
            }
            if self.workflowHit("windows", trimmed) {
                context.windows = WindowList.fetch()
            }
            if self.workflowHit("tabs", trimmed) {
                async let tabs = Task.detached { BrowserTabs.fetch() }.value
                async let history = Task.detached { BookmarkIndex.history() }.value
                context.tabs = await tabs
                context.links += await history
            }
            if self.workflowHit("profiles", trimmed) {
                context.profiles = ChromeProfiles.load()
            }
            if Search.wantsFiles(raw: raw, preferences: context.preferences) {
                let fileQuery = raw.trimmingCharacters(in: .whitespaces)
                let filePreferences = context.preferences
                let files = await Task.detached { FileSearch.files(query: fileQuery, preferences: filePreferences) }.value
                context.files = files
            }
            if let word = Search.wantsDefinition(raw: raw), context.preferences.dictionaryEnabled {
                context.definition = DictionaryLookup.define(word)
            }
            context.forcedResults = forced
            let rows = Search.results(for: raw, context: context)
            await MainActor.run {
                guard token == self.generation else { return }
                self.publishResults(rows)
            }
        }
    }

    func toggleLauncher() {
        if launcherVisible { hideLauncher(reactivate: true) } else { showLauncher() }
    }

    func showLauncher() {
        record(category: "hotkeys")
        previousApp = NSWorkspace.shared.frontmostApplication
        if previousApp?.bundleIdentifier == Bundle.main.bundleIdentifier { previousApp = nil }
        if preferences.showLatestQuery, let date = preferences.lastQueryDate, Date().timeIntervalSince(date) < 300, let latest = preferences.recentQueries.first {
            fromHistory = true
            query = latest
        } else if query.isEmpty {
            results = []
        }
        launcherVisible = true
        focusToken += 1
        SnippetExpander.shared.setSuspended(true)
        NSApp.activate(ignoringOtherApps: true)
        launcher?.show()
        scheduleSearch()
    }

    func hideLauncher(reactivate: Bool) {
        launcherVisible = false
        SnippetExpander.shared.setSuspended(false)
        launcher?.hide()
        if reactivate { previousApp?.activate(options: [.activateIgnoringOtherApps]) }
    }

    func move(_ delta: Int) {
        if query.isEmpty && (results.isEmpty || (delta < 0 && selection == 0)) {
            cycleHistory(delta)
            return
        }
        guard !results.isEmpty else { return }
        selection = min(max(0, selection + delta), results.count - 1)
    }

    func commit(flags: NSEvent.ModifierFlags) {
        guard results.indices.contains(selection) else { return }
        let action = modifierAction(flags)
        run(results[selection], forced: action)
    }

    func commitIndex(_ index: Int) {
        guard results.indices.contains(index) else { return }
        selection = index
        run(results[index], forced: "primary")
    }

    func copySelected() {
        guard results.indices.contains(selection) else { return }
        let item = results[selection]
        writeClipboard(item.kind == "url" ? item.payload : item.subtitle)
    }

    func largeTypeSelected() {
        guard results.indices.contains(selection) else { return }
        let item = results[selection]
        hideLauncher(reactivate: false)
        showLarge(item.kind == "calculation" || item.kind == "copy" ? item.payload : item.title)
    }

    func quickLookSelected() {
        guard preferences.quickLookEnabled, results.indices.contains(selection) else { return }
        let path = results[selection].payload
        guard path.hasPrefix("/") else { return }
        Task.detached { _ = Shell.run("/usr/bin/qlmanage", ["-p", path], timeout: 30) }
    }

    func addBuffer() {
        guard preferences.fileBufferEnabled, results.indices.contains(selection) else { return }
        let item = results[selection]
        guard item.kind == "file" || item.kind == "app" else { return }
        if !fileBuffer.contains(where: { $0.id == item.id }) { fileBuffer.append(item) }
        launcher?.layout()
    }

    func completeSelected() {
        guard results.indices.contains(selection) else { return }
        let item = results[selection]
        if item.kind == "complete" {
            fromHistory = true
            query = item.payload
        } else {
            fromHistory = true
            query = item.title
        }
    }

    func run(_ item: SearchResult, forced: String) {
        if item.kind != "complete" { remember(item) }
        if forced == "web" {
            openWeb(query.isEmpty ? item.title : query)
            hideLauncher(reactivate: false)
            return
        }
        if forced == "finder" {
            searchFinder(query.isEmpty ? item.title : query)
            hideLauncher(reactivate: false)
            return
        }
        if forced == "reveal" {
            reveal(item)
            hideLauncher(reactivate: false)
            return
        }
        if item.kind == "complete" {
            fromHistory = true
            query = item.payload
            return
        }
        record(category: item.category)
        switch item.kind {
        case "app":
            NSWorkspace.shared.open(URL(fileURLWithPath: item.payload))
            hideLauncher(reactivate: false)
        case "file":
            let paths = fileBuffer.isEmpty ? [item.payload] : fileBuffer.map(\.payload)
            for path in paths { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
            fileBuffer = []
            hideLauncher(reactivate: false)
        case "url":
            if let url = URL(string: item.payload) { NSWorkspace.shared.open(url) }
            hideLauncher(reactivate: false)
        case "settings":
            if let url = URL(string: item.payload) { NSWorkspace.shared.open(url) }
            hideLauncher(reactivate: false)
        case "place":
            openPlace(item.payload)
            hideLauncher(reactivate: false)
        case "calculation", "copy", "clipboard", "snippet":
            let text: String
            if item.kind == "snippet" {
                text = expandTokens(snippets.first { $0.id.uuidString == item.payload }?.text ?? item.title)
            } else if item.kind == "clipboard" {
                text = clips.first { $0.id.uuidString == item.payload }?.text ?? item.title
            } else {
                text = item.payload.isEmpty ? item.title : item.payload
            }
            pasteToPrevious(text)
        case "dictionary":
            let body = item.subtitle == "Open Dictionary" ? item.title : item.subtitle
            if let url = URL(string: "dict://\(item.payload.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? item.payload)") {
                NSWorkspace.shared.open(url)
            }
            hideLauncher(reactivate: false)
            showLarge(body)
        case "system":
            performSystem(item.payload)
            hideLauncher(reactivate: false)
        case "process":
            if let pid = Int32(item.payload), pid > 100 {
                if pid == ProcessInfo.processInfo.processIdentifier {
                    NSApp.terminate(nil)
                } else {
                    kill(pid, SIGTERM)
                    debugLine = "Killed \(item.title) (\(pid))"
                }
            }
            hideLauncher(reactivate: false)
        case "window":
            let parts = item.payload.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            let owner = String(parts.first ?? "")
            let title = parts.count > 1 ? String(parts[1]) : ""
            let script = """
            tell application "System Events"
              tell process "\(owner.replacingOccurrences(of: "\"", with: ""))"
                set frontmost to true
                try
                  perform action "AXRaise" of window "\(title.replacingOccurrences(of: "\"", with: ""))"
                end try
              end tell
            end tell
            """
            _ = Shell.osascript(script)
            hideLauncher(reactivate: false)
        case "profile":
            openChromeProfile(item.payload)
            hideLauncher(reactivate: false)
        case "terminal":
            runInTerminal(item.payload)
            hideLauncher(reactivate: false)
        case "shell":
            let command = item.payload
            hideLauncher(reactivate: false)
            Task.detached {
                let output = Shell.run("/bin/zsh", ["-lc", command], timeout: 20)
                await MainActor.run {
                    self.debugLine = output.isEmpty ? "Shell finished" : String(output.prefix(500))
                    if !output.isEmpty { self.writeClipboard(output) }
                }
            }
        case "applescript":
            let source = item.payload
            hideLauncher(reactivate: false)
            Task.detached {
                let output = Shell.osascript(source, timeout: 20)
                await MainActor.run { self.debugLine = output.isEmpty ? "AppleScript finished" : String(output.prefix(500)) }
            }
        case "largetype":
            hideLauncher(reactivate: false)
            showLarge(item.payload)
        case "external":
            let parts = item.payload.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            let uid = String(parts.first ?? "")
            let arg = parts.count > 1 ? String(parts[1]) : ""
            let catalog = scriptCatalog
            hideLauncher(reactivate: false)
            Task.detached {
                ScriptRunner.runAction(catalog: catalog, uid: uid, argument: arg)
                await MainActor.run { self.debugLine = "Ran the workflow action" }
            }
        case "externalchain":
            let parts = item.payload.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            let uid = String(parts.first ?? "")
            let arg = parts.count > 1 ? String(parts[1]) : ""
            let catalog = scriptCatalog
            Task.detached {
                let rows = ScriptRunner.results(catalog: catalog, uid: uid, argument: arg)
                await MainActor.run {
                    guard let rows else {
                        self.debugLine = "The workflow action failed"
                        return
                    }
                    self.results = rows.isEmpty
                        ? [SearchResult(id: "run:empty", title: "No matches", subtitle: arg, icon: "symbol:magnifyingglass", kind: "text", payload: "", category: "action", score: 1)]
                        : rows
                    self.selection = 0
                    self.launcher?.layout()
                }
            }
        case "text":
            hideLauncher(reactivate: false)
            if !item.payload.isEmpty { showLarge(item.payload) }
        default:
            hideLauncher(reactivate: true)
        }
    }

    func record(category: String) {
        usage.append(UsageEvent(date: Date(), category: category))
        if usage.count > 20000 { usage.removeFirst(usage.count - 20000) }
        scheduleSave()
    }

    func preferencesChanged(from old: Preferences) {
        scheduleSave()
        if old.hotkey != preferences.hotkey { applyHotkeys() }
        if old.launchAtLogin != preferences.launchAtLogin { applyLoginItem() }
        if old.snippetsEnabled != preferences.snippetsEnabled { applyExpander() }
        if old.remoteEnabled != preferences.remoteEnabled || old.remotePort != preferences.remotePort || old.remoteLocalOnly != preferences.remoteLocalOnly || old.remoteToken != preferences.remoteToken {
            applyRemote()
        }
        let appRootsChanged = old.scopePaths != preferences.scopePaths || old.includeSystemApps != preferences.includeSystemApps || old.includeUserApps != preferences.includeUserApps || old.includePreferencePanes != preferences.includePreferencePanes || old.scopeApplications != preferences.scopeApplications
        if appRootsChanged {
            reindex()
            IndexWatch.shared.restartApps(preferences)
        }
        if appRootsChanged || old.scopeHome != preferences.scopeHome {
            IndexWatch.shared.restartFiles(preferences)
        }
        if old.onePasswordEnabled != preferences.onePasswordEnabled && preferences.onePasswordEnabled { reloadOnePassword() }
        if old.safariBookmarks != preferences.safariBookmarks || old.chromeBookmarks != preferences.chromeBookmarks { reloadLinks() }
    }

    func workflowsChanged() {
        scheduleSave()
        applyHotkeys()
        if selectedWorkflow == nil { selectedWorkflow = workflows.first?.id }
    }

    func snippetsChanged() {
        scheduleSave()
        applyExpander()
    }

    private func publishResults(_ rows: [SearchResult]) {
        for item in rows.prefix(LauncherMetrics.visibleRows) where item.icon.hasPrefix("file:") {
            _ = IconCache.shared.image(for: String(item.icon.dropFirst("file:".count)))
        }
        results = rows
        if selection >= rows.count { selection = 0 }
        launcher?.layout()
    }

    func reindex() {
        let prefs = preferences
        Task.detached {
            let apps = AppIndexer.applications(preferences: prefs)
            await MainActor.run {
                self.apps = apps
                IconCache.shared.prefetch(apps.map(\.path))
            }
        }
    }

    func reloadLinks() {
        let prefs = preferences
        Task.detached {
            let links = BookmarkIndex.load(preferences: prefs)
            await MainActor.run { self.links = links }
        }
    }

    func reloadOnePassword() {
        Task.detached {
            let items = OnePassword.items()
            await MainActor.run { self.opItems = items }
        }
    }

    func clearAppCache() {
        apps = []
        reindex()
        debugLine = "Application cache cleared"
    }

    func rebuildMetadata() {
        Task.detached {
            _ = Shell.run("/usr/bin/mdimport", ["/Applications"], timeout: 20)
            _ = Shell.run("/usr/bin/mdimport", [NSHomeDirectory()], timeout: 30)
        }
        debugLine = "Asked Spotlight to reindex Applications and Home"
    }

    func clearKnowledge() {
        knowledge = [:]
        selections = [:]
        scheduleSave()
    }

    func clearClipboard() {
        clips = []
        scheduleSave()
    }

    func requestPermissions() {
        _ = Accessibility.prompt()
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func revealSupportFolder() {
        let url = supportDirectory()
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func chooseSupportFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            preferences.syncFolder = url.path
            preferencesChanged(from: preferences)
        }
    }

    func addScopeFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Add"
        if panel.runModal() == .OK, let url = panel.url {
            preferences.scopePaths.append(url.path)
        }
    }

    func showPreferences() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = preferencesWindow() {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
            return
        }
        AppRuntime.openPreferences?()
    }

    func notePreferencesWindow(_ window: NSWindow) {
        window.identifier = NSUserInterfaceItemIdentifier("preferences")
        NSApp.setActivationPolicy(.regular)
        guard observedPreferencesWindow !== window else { return }
        if let preferencesCloseObserver {
            NotificationCenter.default.removeObserver(preferencesCloseObserver)
        }
        observedPreferencesWindow = window
        preferencesCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] note in
            let closing = note.object as? NSWindow
            MainActor.assumeIsolated {
                DispatchQueue.main.async { self?.syncActivationPolicy(ignoring: closing) }
            }
        }
    }

    private weak var observedPreferencesWindow: NSWindow?
    private var preferencesCloseObserver: NSObjectProtocol?

    private func preferencesWindow() -> NSWindow? {
        NSApp.windows.first { window in
            guard window.isVisible, !window.isKind(of: NSPanel.self) else { return false }
            return window.identifier?.rawValue == "preferences" || window.title.contains("Preferences")
        }
    }

    private func syncActivationPolicy(ignoring closed: NSWindow? = nil) {
        let showDock = NSApp.windows.contains { window in
            guard window !== closed, window.isVisible, !window.isKind(of: NSPanel.self) else { return false }
            return window.identifier?.rawValue == "preferences" || window.title.contains("Preferences")
        }
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
    }

    func handleRemote(_ target: String) -> String {
        record(category: "remote")
        let parts = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = String(parts.first ?? "/")
        let query = parts.count > 1 ? String(parts[1]) : ""
        let params = queryItems(query)
        guard params["token"] == preferences.remoteToken else {
            return "<p>Token required. Add ?token= from Jfred Preferences → Remote.</p>"
        }
        if path == "/run" {
            let id = params["id"] ?? ""
            performSystem(id)
            return "<p>Ran \(id). <a href=\"/?token=\(preferences.remoteToken)\">Back</a></p>"
        }
        if path == "/open" {
            let value = params["path"] ?? ""
            if value.hasPrefix("http"), let url = URL(string: value) {
                NSWorkspace.shared.open(url)
            } else if value.hasPrefix("/") {
                NSWorkspace.shared.open(URL(fileURLWithPath: value))
            }
            return "<p>Opened. <a href=\"/?token=\(preferences.remoteToken)\">Back</a></p>"
        }
        let q = params["q"] ?? ""
        var body = """
        <!doctype html><meta charset="utf-8"><title>Jfred Remote</title>
        <style>body{font:15px -apple-system,sans-serif;background:#1b1b1b;color:#f2f2f2;margin:28px}a{color:#d7b4ff;text-decoration:none}input,button{font:inherit;padding:6px 8px}li{margin:6px 0}</style>
        <h1>Jfred Remote</h1>
        <form><input type="hidden" name="token" value="\(preferences.remoteToken)"><input name="q" value="\(escapeHTML(q))" placeholder="Search" autofocus><button>Search</button></form>
        """
        if !q.isEmpty {
            let rows = Search.results(for: q, context: makeContext(files: [], windows: [], processes: [], tabs: [], profiles: [], definition: nil))
            body += "<ul>"
            for row in rows {
                let href: String
                if row.kind == "system" {
                    href = "/run?token=\(preferences.remoteToken)&id=\(row.payload)"
                } else if row.kind == "app" || row.kind == "url" || row.kind == "file" {
                    let value = row.payload.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    href = "/open?token=\(preferences.remoteToken)&path=\(value)"
                } else {
                    continue
                }
                body += "<li><a href=\"\(href)\">\(escapeHTML(row.title))</a><br><small>\(escapeHTML(row.subtitle))</small></li>"
            }
            body += "</ul>"
        } else {
            body += "<h2>\(remoteCategory.title)</h2><ul>"
            switch remoteCategory {
            case .system:
                for command in SystemCommand.all {
                    body += "<li><a href=\"/run?token=\(preferences.remoteToken)&id=\(command.id)\">\(command.title)</a></li>"
                }
            case .applications:
                for app in apps.prefix(40) {
                    let value = app.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    body += "<li><a href=\"/open?token=\(preferences.remoteToken)&path=\(value)\">\(escapeHTML(app.name))</a></li>"
                }
            case .preferences:
                for setting in SettingsCatalog.all {
                    let value = setting.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    body += "<li><a href=\"/open?token=\(preferences.remoteToken)&path=\(value)\">\(setting.name)</a></li>"
                }
            case .folders:
                body += "<li><a href=\"/open?token=\(preferences.remoteToken)&path=\(NSHomeDirectory())\">Home</a></li>"
            case .bookmarks:
                for link in links.prefix(40) {
                    let value = link.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    body += "<li><a href=\"/open?token=\(preferences.remoteToken)&path=\(value)\">\(escapeHTML(link.title))</a></li>"
                }
            }
            body += "</ul>"
        }
        return body
    }

    private func queryItems(_ query: String) -> [String: String] {
        var items: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let bits = pair.split(separator: "=", maxSplits: 1)
            let key = String(bits.first ?? "")
            let value = bits.count > 1 ? String(bits[1]).removingPercentEncoding ?? String(bits[1]) : ""
            items[key] = value
        }
        return items
    }

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    private func modifierAction(_ flags: NSEvent.ModifierFlags) -> String {
        if flags.contains(.command) { return preferences.modifierCommand }
        if flags.contains(.option) { return preferences.modifierOption }
        if flags.contains(.control) { return preferences.modifierControl }
        return "primary"
    }

    private func remember(_ item: SearchResult) {
        let key = fold(query)
        if preferences.topResultLatching && !key.isEmpty { knowledge[key] = item.id }
        var stat = selections[item.id] ?? SelectionStat(count: 0, lastSelected: Date())
        stat.count += 1
        stat.lastSelected = Date()
        selections[item.id] = stat
        if preferences.storeTypedQuery && !query.trimmingCharacters(in: .whitespaces).isEmpty {
            preferences.recentQueries.removeAll { $0 == query }
            preferences.recentQueries.insert(query, at: 0)
            if preferences.recentQueries.count > 20 { preferences.recentQueries.removeLast(preferences.recentQueries.count - 20) }
            preferences.lastQueryDate = Date()
        }
        scheduleSave()
    }

    private func cycleHistory(_ delta: Int) {
        let items = preferences.recentQueries
        guard !items.isEmpty else { return }
        let next = (historyCursor ?? -1) + (delta < 0 ? 1 : -1)
        let index = min(max(0, next), items.count - 1)
        historyCursor = index
        fromHistory = true
        query = items[index]
    }

    private func workflowHit(_ builtin: String, _ trimmed: String) -> Bool {
        guard let workflow = workflows.first(where: { $0.enabled && $0.builtin == builtin }) else { return false }
        return WorkflowMatching.best(in: [workflow], query: trimmed) != nil
    }

    private func makeContext(files: [AppRecord], windows: [WindowInfo], processes: [ProcInfo], tabs: [LinkRecord], profiles: [ProfileInfo], definition: String?, forced: [SearchResult]? = nil) -> SearchContext {
        SearchContext(
            preferences: preferences,
            workflows: workflows,
            snippets: snippets,
            apps: apps,
            places: places(),
            settings: SettingsCatalog.all,
            links: links,
            contacts: contacts,
            clips: clips,
            files: files,
            windows: windows,
            processes: processes,
            tabs: tabs,
            profiles: profiles,
            definition: definition,
            opItems: opItems,
            knowledge: knowledge,
            selections: selections,
            now: Date(),
            forcedResults: forced
        )
    }

    private func places() -> [AppRecord] {
        let home = NSHomeDirectory()
        return [
            AppRecord(id: "computer", name: "Computer", path: ""),
            AppRecord(id: "home", name: "Home", path: home),
            AppRecord(id: "desktop", name: "Desktop", path: (home as NSString).appendingPathComponent("Desktop")),
            AppRecord(id: "documents", name: "Documents", path: (home as NSString).appendingPathComponent("Documents")),
            AppRecord(id: "downloads", name: "Downloads", path: (home as NSString).appendingPathComponent("Downloads")),
            AppRecord(id: "applications", name: "Applications", path: "/Applications"),
            AppRecord(id: "trash", name: "Trash", path: (home as NSString).appendingPathComponent(".Trash")),
        ]
    }

    private func openPlace(_ id: String) {
        switch id {
        case "computer":
            _ = Shell.osascript("""
            tell application "Finder"
              activate
              if (count of Finder windows) is 0 then make new Finder window
              set target of front Finder window to computer container
            end tell
            """)
        case "trash":
            _ = Shell.osascript("tell application \"Finder\" to open trash")
        default:
            if let place = places().first(where: { $0.id == id }) {
                NSWorkspace.shared.open(URL(fileURLWithPath: place.path))
            }
        }
    }

    private func openWeb(_ text: String) {
        let search = preferences.webSearches.first { $0.enabled && $0.fallback } ?? preferences.webSearches[0]
        if let url = URL(string: preferences.resolvedURL(for: search, query: text)) {
            NSWorkspace.shared.open(url)
        }
    }

    private func searchFinder(_ text: String) {
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        _ = Shell.osascript("""
        tell application "Finder" to activate
        delay 0.15
        tell application "System Events" to tell process "Finder"
          keystroke "f" using command down
          delay 0.15
          keystroke "\(escaped)"
        end tell
        """)
    }

    private func reveal(_ item: SearchResult) {
        let path = item.payload
        guard path.hasPrefix("/") else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func pasteToPrevious(_ text: String) {
        let restore = preferences.selectionHotkeyMode == "restore"
        let board = NSPasteboard.general
        let previous = board.string(forType: .string)
        board.clearContents()
        board.setString(text, forType: .string)
        hideLauncher(reactivate: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            postKey(9, flags: .maskCommand)
            if restore {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    board.clearContents()
                    if let previous { board.setString(previous, forType: .string) }
                }
            }
        }
    }

    private func writeClipboard(_ text: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
    }

    func showLarge(_ text: String) {
        launcher?.showLarge(text, size: preferences.largeTypeSize, font: preferences.largeTypeFont)
    }

    private func performSystem(_ id: String) {
        if id.hasPrefix("volume:") {
            let value = id.dropFirst("volume:".count)
            _ = Shell.osascript("set volume output volume \(value)")
            return
        }
        switch id {
        case "sleep": _ = Shell.osascript("tell application \"System Events\" to sleep")
        case "restart": _ = Shell.osascript("tell application \"System Events\" to restart")
        case "shutdown": _ = Shell.osascript("tell application \"System Events\" to shut down")
        case "logout": _ = Shell.osascript("tell application \"System Events\" to log out")
        case "lock": _ = Shell.osascript("tell application \"System Events\" to keystroke \"q\" using {command down, control down}")
        case "screensaver": _ = Shell.run("/usr/bin/open", ["-a", "ScreenSaverEngine"])
        case "emptetrash": _ = Shell.osascript("tell application \"Finder\" to empty trash")
        case "eject": _ = Shell.osascript("tell application \"Finder\" to eject (every disk whose ejectable is true)")
        case "quitall":
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                app.terminate()
            }
        case "darkmode":
            _ = Shell.osascript("tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode")
        case "hidden":
            let current = Shell.run("/usr/bin/defaults", ["read", "com.apple.finder", "AppleShowAllFiles"])
            let next = current.trimmingCharacters(in: .whitespacesAndNewlines) == "1" ? "false" : "true"
            _ = Shell.run("/usr/bin/defaults", ["write", "com.apple.finder", "AppleShowAllFiles", "-bool", next])
            _ = Shell.run("/usr/bin/killall", ["Finder"])
        case "desktop": postKey(103)
        case "mission": NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
        case "launchpad":
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.launchpad.launcher") {
                NSWorkspace.shared.open(url)
            }
        case "screenshot":
            Task.detached { _ = Shell.run("/usr/sbin/screencapture", ["-i"], timeout: 60) }
        case "mute": _ = Shell.osascript("set volume with output muted")
        case "volumeup": changeVolume(10)
        case "volumedown": changeVolume(-10)
        default:
            debugLine = "Unknown command \(id)"
        }
    }

    private func changeVolume(_ delta: Int) {
        let text = Shell.osascript("output volume of (get volume settings)")
        let current = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 50
        let next = min(100, max(0, current + delta))
        _ = Shell.osascript("set volume output volume \(next)")
    }

    private func openChromeProfile(_ directory: String) {
        let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--profile-directory=\(directory)"]
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: chrome, configuration: config) { _, _ in }
    }

    private func runInTerminal(_ command: String) {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        switch preferences.terminalApp {
        case "iTerm":
            _ = Shell.osascript("""
            tell application "iTerm"
              activate
              create window with default profile
              tell current session of current window to write text "\(escaped)"
            end tell
            """)
        case "Ghostty":
            _ = Shell.run("/usr/bin/open", ["-na", "Ghostty", "--args", "-e", "/bin/zsh", "-lc", command])
        case "Alacritty":
            _ = Shell.run("/usr/bin/open", ["-na", "Alacritty", "--args", "-e", "/bin/zsh", "-lc", command])
        default:
            _ = Shell.osascript("""
            tell application "Terminal"
              activate
              do script "\(escaped)"
            end tell
            """)
        }
    }

    func applyHotkeys() {
        let ok = HotkeyCenter.shared.register(id: 1, keyCode: UInt32(preferences.hotkey.keyCode), modifiers: preferences.hotkey.carbonModifiers) { [weak self] in
            Task { @MainActor in self?.toggleLauncher() }
        }
        if ok {
            hotkeyWarning = ""
        } else {
            hotkeyWarning = "That hotkey is already in use. Pick another."
            if knowledge["statusItem"] == "hidden" {
                knowledge["statusItem"] = "shown"
                refreshStatusItem()
            }
        }
        for (index, workflow) in workflows.enumerated() {
            let id = UInt32(100 + index)
            guard let hotkey = workflow.hotkey, workflow.enabled else {
                HotkeyCenter.shared.unregister(id: id)
                continue
            }
            let keyword = workflow.keyword
            _ = HotkeyCenter.shared.register(id: id, keyCode: UInt32(hotkey.keyCode), modifiers: hotkey.carbonModifiers) { [weak self] in
                Task { @MainActor in
                    self?.query = keyword + " "
                    self?.showLauncher()
                }
            }
        }
    }

    func applyLoginItem() {
        do {
            if preferences.launchAtLogin {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            hotkeyWarning = "Login item needs the app to live in a stable folder. \(error.localizedDescription)"
        }
    }

    func applyExpander() {
        SnippetExpander.shared.update(enabled: preferences.snippetsEnabled, snippets: snippets)
    }

    func applyRemote() {
        remote.handle = { [weak self] target in
            self?.handleRemote(target) ?? "Unavailable"
        }
        if preferences.remoteEnabled {
            remoteWarning = remote.start(port: UInt16(preferences.remotePort), localOnly: preferences.remoteLocalOnly) ?? ""
        } else {
            remote.stop()
            remoteWarning = ""
        }
    }

    private func pollClipboard() {
        let board = NSPasteboard.general
        guard preferences.clipboardEnabled, board.changeCount != clipChange else { return }
        clipChange = board.changeCount
        guard let text = board.string(forType: .string), !text.isEmpty else { return }
        if clips.first?.text == text { return }
        clips.insert(ClipItem(text: String(text.prefix(20_000)), date: Date()), at: 0)
        if clips.count > preferences.clipboardLimit { clips = Array(clips.prefix(preferences.clipboardLimit)) }
        scheduleSave()
    }

    private func supportDirectory() -> URL {
        let url = SupportPaths.directory(syncFolder: preferences.syncFolder)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func load() {
        let url = supportDirectory().appendingPathComponent("state.json")
        guard let data = try? Data(contentsOf: url), let state = try? JSONDecoder().decode(DiskState.self, from: data) else {
            preferences = Preferences()
            workflows = Seed.workflows()
            snippets = Seed.snippets()
            finishJfredStore()
            return
        }
        preferences = state.preferences
        workflows = state.workflows
        snippets = state.snippets
        clips = state.clips
        usage = state.usage
        knowledge = state.knowledge
        selections = state.selections
        finishJfredStore()
    }

    private func finishJfredStore() {
        if knowledge["launcher.sync"] != "1", let catalog = JfredStore.apply(self) {
            knowledge["launcher.sync"] = "1"
            scriptCatalog = catalog
            scheduleSave()
        } else {
            scriptCatalog = JfredStore.catalog()
        }
    }

    func importLauncherSettings() {
        guard let catalog = JfredStore.apply(self) else { return }
        knowledge["launcher.sync"] = "1"
        scriptCatalog = catalog
        applyHotkeys()
        applyExpander()
        refreshStatusItem()
        scheduleSave()
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func save() {
        let state = DiskState(preferences: preferences, workflows: workflows, snippets: snippets, clips: clips, usage: usage, knowledge: knowledge, selections: selections)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: supportDirectory().appendingPathComponent("state.json"), options: .atomic)
    }

    private func refreshStatusItem() {
        if showStatusItem {
            if statusItem == nil { installStatusItem() }
            return
        }
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = menuHatImage()
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Jfred", action: #selector(statusShow), keyEquivalent: "")
        menu.addItem(withTitle: "Preferences", action: #selector(statusPrefs), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Jfred", action: #selector(statusQuit), keyEquivalent: "q")
        for entry in menu.items { entry.target = self }
        item.menu = menu
        statusItem = item
    }

    private var statusItem: NSStatusItem?

    @objc private func statusShow() { showLauncher() }
    @objc private func statusPrefs() { showPreferences() }
    @objc private func statusQuit() { NSApp.terminate(nil) }
}

enum PrefSection: String, CaseIterable, Identifiable {
    case general, features, workflows, appearance, remote, advanced, usage, update
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "General"
        case .features: "Features"
        case .workflows: "Workflows"
        case .appearance: "Appearance"
        case .remote: "Remote"
        case .advanced: "Advanced"
        case .usage: "Usage"
        case .update: "Update"
        }
    }
    var symbol: String {
        switch self {
        case .general: "hat"
        case .features: "checkmark"
        case .workflows: "square.grid.2x2"
        case .appearance: "paintbrush.fill"
        case .remote: "antenna.radiowaves.left.and.right"
        case .advanced: "slider.horizontal.3"
        case .usage: "chart.xyaxis.line"
        case .update: "square.and.arrow.down"
        }
    }
}

enum AppRelease {
    static var version: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        if let raw, !raw.isEmpty { return raw }
        return "0.1.0"
    }
}

enum FeatureID: String, CaseIterable, Identifiable {
    case defaultResults, fileSearch, universalActions, webSearch, bookmarks, clipboard, snippets, calculator, dictionary, onePassword, system, terminal, largeType, previews
    var id: String { rawValue }
    var title: String {
        switch self {
        case .defaultResults: "Default Results"
        case .fileSearch: "File Search"
        case .universalActions: "Universal Actions"
        case .webSearch: "Web Search"
        case .bookmarks: "Web Bookmarks"
        case .clipboard: "Clipboard History"
        case .snippets: "Snippets"
        case .calculator: "Calculator"
        case .dictionary: "Dictionary"
        case .onePassword: "1Password"
        case .system: "System"
        case .terminal: "Terminal"
        case .largeType: "Large Type"
        case .previews: "Previews"
        }
    }
    var subtitle: String {
        switch self {
        case .defaultResults: "Scope, Types, Fallbacks"
        case .fileSearch: "Search, Navigation, Buffer"
        case .universalActions: "Files, Text, URLs"
        case .webSearch: "Custom, URLs, History"
        case .bookmarks: "Safari, Chrome"
        case .clipboard: "History, Merging"
        case .snippets: "Snippets, Clippings"
        case .calculator: "Standard, Advanced"
        case .dictionary: "Spelling, Definitions"
        case .onePassword: "1Click Bookmarks"
        case .system: "Commands, Quitting, Ejecting"
        case .terminal: "Prefix, Custom Integration"
        case .largeType: "Display, Font"
        case .previews: "Quick Look, Preview panels"
        }
    }
    var symbol: String {
        switch self {
        case .defaultResults: "magnifyingglass"
        case .fileSearch: "doc.text.magnifyingglass"
        case .universalActions: "arrow.right.square"
        case .webSearch: "globe"
        case .bookmarks: "bookmark.fill"
        case .clipboard: "list.clipboard"
        case .snippets: "note.text"
        case .calculator: "plus.slash.minus"
        case .dictionary: "character.book.closed.fill"
        case .onePassword: "key.fill"
        case .system: "power"
        case .terminal: "terminal.fill"
        case .largeType: "textformat.size"
        case .previews: "eye"
        }
    }
}

enum RemoteCategory: String, CaseIterable, Identifiable {
    case system, applications, preferences, folders, bookmarks
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System Commands"
        case .applications: "Applications"
        case .preferences: "Preferences"
        case .folders: "Folders and Files"
        case .bookmarks: "Bookmarks"
        }
    }
    var subtitle: String {
        switch self {
        case .system: "Control your Mac"
        case .applications: "Launch your Applications"
        case .preferences: "Launch macOS Preferences"
        case .folders: "Open your Folders and Files"
        case .bookmarks: "URLs and Custom Searches"
        }
    }
    var symbol: String {
        switch self {
        case .system: "power"
        case .applications: "folder"
        case .preferences: "gearshape"
        case .folders: "house"
        case .bookmarks: "globe"
        }
    }
}

struct PreferenceHit: Identifiable {
    var id: String
    var title: String
    var detail: String
    var section: PrefSection
    var feature: FeatureID?
}

enum PreferenceIndex {
    static let hits: [PreferenceHit] = {
        var rows: [PreferenceHit] = [
            PreferenceHit(id: "login", title: "Launch at login", detail: "General", section: .general, feature: nil),
            PreferenceHit(id: "hotkey", title: "Jfred Hotkey", detail: "General", section: .general, feature: nil),
            PreferenceHit(id: "location", title: "Where are you", detail: "Google and Amazon domains", section: .general, feature: nil),
            PreferenceHit(id: "permissions", title: "Permissions", detail: "Accessibility and automation", section: .general, feature: nil),
            PreferenceHit(id: "cache", title: "Clear Application Cache", detail: "Advanced", section: .advanced, feature: nil),
            PreferenceHit(id: "metadata", title: "Rebuild macOS Metadata", detail: "Advanced", section: .advanced, feature: nil),
            PreferenceHit(id: "history", title: "Store typed query", detail: "Advanced", section: .advanced, feature: nil),
            PreferenceHit(id: "learning", title: "Top Result Keyword Latching", detail: "Advanced", section: .advanced, feature: nil),
            PreferenceHit(id: "sync", title: "Syncing folder", detail: "Advanced", section: .advanced, feature: nil),
            PreferenceHit(id: "usage", title: "Usage", detail: "Stats", section: .usage, feature: nil),
            PreferenceHit(id: "theme", title: "Appearance themes", detail: "Jfred Modern and others", section: .appearance, feature: nil),
            PreferenceHit(id: "remote", title: "Remote server", detail: "Local command page", section: .remote, feature: nil),
        ]
        for feature in FeatureID.allCases {
            rows.append(PreferenceHit(id: feature.id, title: feature.title, detail: feature.subtitle, section: .features, feature: feature))
        }
        return rows
    }()
}
