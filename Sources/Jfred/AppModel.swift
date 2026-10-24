import AppKit
import JfredCore
import Foundation
import ServiceManagement

enum AppRuntime {
    @MainActor static var model: AppModel?
    @MainActor static var openPreferences: (() -> Void)?
    /// Quit Jfred, the status menu, and killing this process. Dock Quit stays resident.
    @MainActor static var explicitQuit = false
    /// True when macOS started Jfred as a login item; don't steal focus then.
    @MainActor static var launchedAsLoginItem = false
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
        []
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
    var musicTrack = ""
    var musicSearch = ""
    var musicTracks: [MusicService.Track] = []
    var musicNowTitle = ""
    var musicNowArtist = ""
    var musicNowPlaying = false
    var contactsTab = "Contacts"
    var musicTab = "General"
    var actionsTab = "General"
    var showRemoteQR = false
    var showSnippetExpansionOptions = false
    var workflowSelection: Int? = nil
    var workflowDragIndex: Int? = nil
    private var transientItem: SearchResult?
    var debuggerVisible = false
    var debugLines: [String] = []
    var debugQuery = "test"
    var debugCursor = 0
    var debugWorkflowID: UUID?
    var debugBreakpoints: Set<Int> = []
    var debugPaused = false
    var showThemeEditor = false
    var helpQuery = ""
    var selectionHotkeyWarning = ""
    var actionPanelVisible = false
    var actionIndex = 0
    var launcherActions: [LauncherAction] = []
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
    var fileSearchTab = "Search"
    var clipboardTab = "History"
    var snippetCollectionFilter = ""
    var snippetSearch = ""
    var selectedSnippetID: UUID?
    var webSearchTab = "Search"
    var webSearchFilter = ""
    var webSearchOnlyEnabled = false
    var selectedWebSearchID: String?
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
    private var fileBufferLastUsed: Date?
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
        reloadContacts()
        if preferences.onePasswordEnabled { reloadOnePassword() }
        syncActivationPolicy()
        IndexWatch.shared.start(preferences: preferences) { [weak self] in
            self?.reindex()
        }
        clipChange = NSPasteboard.general.changeCount
        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollClipboard()
                self?.pruneFileBuffer()
            }
        }
    }

    func scheduleSearch() {
        if transientItem != nil {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
            transientItem = nil
        }
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
        transientItem = nil
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
        actionPanelVisible = false
        focusToken += 1
        SnippetExpander.shared.setSuspended(true)
        if previousApp != nil { sinkPreferencesBehindOtherApps() }
        launcher?.show()
        scheduleSearch()
    }

    func hideLauncher(reactivate: Bool) {
        transientItem = nil
        launcherVisible = false
        SnippetExpander.shared.setSuspended(false)
        launcher?.hide()
        if reactivate, let previousApp {
            previousApp.activate(options: [.activateIgnoringOtherApps])
            DispatchQueue.main.async { self.restorePreferencesLevel() }
        } else {
            restorePreferencesLevel()
        }
    }

    private var preferencesLevelBeforeLauncher: NSWindow.Level?

    /// Preferences is a normal window. Once this app activates, macOS raises it
    /// over Finder. Drop it below normal windows while the launcher is up.
    private func sinkPreferencesBehindOtherApps() {
        guard let window = preferencesWindow(), preferencesLevelBeforeLauncher == nil else { return }
        preferencesLevelBeforeLauncher = window.level
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1)
    }

    private func restorePreferencesLevel() {
        guard let window = preferencesWindow(), let level = preferencesLevelBeforeLauncher else {
            preferencesLevelBeforeLauncher = nil
            return
        }
        preferencesLevelBeforeLauncher = nil
        window.level = level
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

    func showActions() {
        guard results.indices.contains(selection) else { return }
        launcherActions = actions(for: results[selection])
        guard !launcherActions.isEmpty else { return }
        actionPanelVisible = true
        actionIndex = 0
        launcher?.layout()
    }

    func closeActions() {
        guard actionPanelVisible else { return }
        actionPanelVisible = false
        actionIndex = 0
        launcher?.layout()
    }

    func moveAction(_ delta: Int) {
        guard actionPanelVisible, !launcherActions.isEmpty else { return }
        actionIndex = (actionIndex + delta + launcherActions.count) % launcherActions.count
    }

    func commitAction() {
        guard actionPanelVisible, launcherActions.indices.contains(actionIndex), results.indices.contains(selection) else { return }
        let item = results[selection]
        let action = launcherActions[actionIndex]
        let value = item.payload.isEmpty ? item.title : item.payload
        closeActions()
        switch action.kind {
        case .open:
            run(item, forced: "primary")
        case .reveal:
            reveal(item)
            hideLauncher(reactivate: false)
        case .copyPath:
            writeClipboard(value)
            hideLauncher(reactivate: false)
        case .copyName:
            writeClipboard(item.title)
            hideLauncher(reactivate: false)
        case .copyValue:
            writeClipboard(value)
            hideLauncher(reactivate: false)
        case .openBrowser:
            if let url = URL(string: value) { NSWorkspace.shared.open(url) }
            hideLauncher(reactivate: false)
        case .quickLook:
            quickLookSelected()
        case .largeType:
            largeTypeSelected()
        case .pasteClipboard:
            if let clip = clips.first(where: { $0.id.uuidString == item.payload }) { pasteClipboardItem(clip) }
        case .pasteValue:
            pasteToPrevious(value)
        case .email:
            if let contact = contacts.first(where: { ($0.uid ?? $0.id) == item.payload }),
               !contact.email.isEmpty,
               let url = URL(string: "mailto:\(contact.email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? contact.email)") {
                NSWorkspace.shared.open(url)
            }
            hideLauncher(reactivate: false)
        case .call:
            if let contact = contacts.first(where: { ($0.uid ?? $0.id) == item.payload }) {
                let digits = contact.phone.filter { $0.isNumber || $0 == "+" }
                if !digits.isEmpty, let url = URL(string: "tel:\(digits)") {
                    NSWorkspace.shared.open(url)
                }
            }
            hideLauncher(reactivate: false)
        case .searchWeb:
            let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                NSWorkspace.shared.open(url)
            }
            hideLauncher(reactivate: false)
        }
    }

    private func actions(for item: SearchResult) -> [LauncherAction] {
        var actions: [LauncherAction] = []
        switch item.kind {
        case "app", "file", "place":
            actions.append(LauncherAction(kind: .open, title: "Open", subtitle: item.title, symbol: "arrow.up.forward.app"))
            if item.payload.hasPrefix("/") {
                actions.append(LauncherAction(kind: .reveal, title: "Reveal in Finder", subtitle: item.payload, symbol: "folder"))
                actions.append(LauncherAction(kind: .copyPath, title: "Copy Path", subtitle: item.payload, symbol: "doc.on.doc"))
                actions.append(LauncherAction(kind: .quickLook, title: "Quick Look", subtitle: "Preview the selected item", symbol: "eye"))
            }
            actions.append(LauncherAction(kind: .copyName, title: "Copy Name", subtitle: item.title, symbol: "textformat"))
            actions.append(LauncherAction(kind: .largeType, title: "Large Type", subtitle: item.title, symbol: "textformat.size"))
        case "url":
            actions.append(LauncherAction(kind: .open, title: "Open URL", subtitle: item.payload, symbol: "safari"))
            actions.append(LauncherAction(kind: .openBrowser, title: "Open in Default Browser", subtitle: item.payload, symbol: "globe"))
            actions.append(LauncherAction(kind: .copyValue, title: "Copy URL", subtitle: item.payload, symbol: "doc.on.doc"))
            actions.append(LauncherAction(kind: .largeType, title: "Large Type", subtitle: item.title, symbol: "textformat.size"))
        case "contact":
            actions.append(LauncherAction(kind: .open, title: "Open Contact", subtitle: item.title, symbol: "person.crop.circle"))
            if let contact = contacts.first(where: { ($0.uid ?? $0.id) == item.payload }) {
                if !contact.email.isEmpty {
                    actions.append(LauncherAction(kind: .email, title: "Email", subtitle: contact.email, symbol: "envelope"))
                }
                if !contact.phone.isEmpty {
                    actions.append(LauncherAction(kind: .call, title: "Call", subtitle: contact.phone, symbol: "phone"))
                }
            }
            actions.append(LauncherAction(kind: .copyValue, title: "Copy Email or Phone", subtitle: item.subtitle, symbol: "doc.on.doc"))
            actions.append(LauncherAction(kind: .largeType, title: "Large Type", subtitle: item.title, symbol: "textformat.size"))
        case "clipboard":
            actions.append(LauncherAction(kind: .pasteClipboard, title: "Paste", subtitle: item.title, symbol: "doc.on.clipboard"))
            actions.append(LauncherAction(kind: .copyName, title: "Copy", subtitle: item.title, symbol: "doc.on.doc"))
            actions.append(LauncherAction(kind: .largeType, title: "Large Type", subtitle: item.title, symbol: "textformat.size"))
        case "text":
            actions.append(LauncherAction(kind: .copyValue, title: "Copy", subtitle: item.title, symbol: "doc.on.doc"))
            actions.append(LauncherAction(kind: .largeType, title: "Large Type", subtitle: item.title, symbol: "textformat.size"))
            if let url = URL(string: item.payload), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                actions.append(LauncherAction(kind: .openBrowser, title: "Open as URL", subtitle: item.payload, symbol: "safari"))
            } else {
                actions.append(LauncherAction(kind: .searchWeb, title: "Search the Web", subtitle: "Google", symbol: "magnifyingglass"))
            }
        default:
            if item.kind == "calculation" || item.kind == "copy" || item.kind == "snippet" {
                actions.append(LauncherAction(kind: .pasteValue, title: "Paste", subtitle: item.title, symbol: "doc.on.clipboard"))
                actions.append(LauncherAction(kind: .copyValue, title: "Copy", subtitle: item.title, symbol: "doc.on.doc"))
            } else {
                actions.append(LauncherAction(kind: .open, title: "Run", subtitle: item.title, symbol: "return"))
                actions.append(LauncherAction(kind: .copyName, title: "Copy", subtitle: item.title, symbol: "doc.on.doc"))
            }
            actions.append(LauncherAction(kind: .largeType, title: "Large Type", subtitle: item.title, symbol: "textformat.size"))
        }
        return actions
    }

    func copySelected() {
        guard results.indices.contains(selection) else { return }
        let item = results[selection]
        writeClipboard(item.kind == "url" ? item.payload : item.subtitle)
    }

    func largeTypeSelected() {
        guard results.indices.contains(selection) else { return }
        let item = results[selection]
        if preferences.largeTypeAutoHide {
            hideLauncher(reactivate: false)
        }
        showLarge(item.kind == "calculation" || item.kind == "copy" ? item.payload : item.title)
    }

    func quickLookSelected() {
        guard preferences.quickLookEnabled, results.indices.contains(selection) else { return }
        let path = results[selection].payload
        guard path.hasPrefix("/") else { return }
        if preferences.noPreviewPaths.contains(where: { !$0.isEmpty && path.hasPrefix($0) }) { return }
        let ext = (path as NSString).pathExtension.lowercased()
        if !ext.isEmpty, preferences.noPreviewTypes.contains(where: { $0.lowercased() == ext || $0.lowercased() == "public.\(ext)" }) { return }
        Task.detached { _ = Shell.run("/usr/bin/qlmanage", ["-p", path], timeout: 30) }
    }

    func addBuffer() {
        guard preferences.fileBufferEnabled, results.indices.contains(selection) else { return }
        let item = results[selection]
        guard item.kind == "file" || item.kind == "app" else { return }
        if !fileBuffer.contains(where: { $0.id == item.id }) { fileBuffer.append(item) }
        fileBufferLastUsed = Date()
        launcher?.layout()
    }

    func pruneFileBuffer() {
        guard preferences.fileBufferEnabled, !fileBuffer.isEmpty, let last = fileBufferLastUsed else { return }
        let timeout = TimeInterval(max(1, preferences.fileBufferTimeoutMinutes) * 60)
        if Date().timeIntervalSince(last) >= timeout {
            fileBuffer = []
            fileBufferLastUsed = nil
            launcher?.layout()
        }
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
            if preferences.fileOpenWithFinder {
                NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
            } else {
                for path in paths { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
            }
            if preferences.fileClearBufferAfterAction {
                fileBuffer = []
                fileBufferLastUsed = nil
            }
            hideLauncher(reactivate: false)
        case "url":
            if let url = URL(string: item.payload) {
                if preferences.bookmarkOpenMode == "source", item.id.hasPrefix("link:") {
                    openInSourceBrowser(url, linkID: item.id)
                } else {
                    NSWorkspace.shared.open(url)
                }
                noteURLHistory(item.payload)
            }
            hideLauncher(reactivate: false)
        case "settings":
            if let url = URL(string: item.payload) { NSWorkspace.shared.open(url) }
            hideLauncher(reactivate: false)
        case "place":
            openPlace(item.payload)
            hideLauncher(reactivate: false)
        case "snippets":
            query = preferences.snippetKeyword.trimmingCharacters(in: .whitespaces) + " "
            scheduleSearch()
        case "clipclear":
            if let minutes = Int(item.payload) { clearClipboardHistory(lastMinutes: minutes) } else { clearClipboardHistory() }
            hideLauncher(reactivate: false)
        case "clipboard":
            if let clip = clips.first(where: { $0.id.uuidString == item.payload }) {
                pasteClipboardItem(clip)
            }
        case "calculation", "copy", "snippet":
            let text: String
            if item.kind == "snippet" {
                text = expandTokens(snippets.first { $0.id.uuidString == item.payload }?.text ?? item.title)
            } else {
                text = item.payload.isEmpty ? item.title : item.payload
            }
            pasteToPrevious(text)
        case "contact":
            let uid = item.payload
            let contact = contacts.first { ($0.uid ?? $0.id) == uid }
            if preferences.contactsOpenInAlfred, let contact {
                let details = [contact.name, contact.email, contact.phone, contact.jobTitle ?? "", contact.organization ?? ""]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                hideLauncher(reactivate: false)
                showLarge(details)
            } else if preferences.contactsURLHandlerEnabled, !preferences.contactsURLHandler.isEmpty {
                let encoded = uid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? uid
                let template = preferences.contactsURLHandler.replacingOccurrences(of: "{uid}", with: encoded)
                if let url = URL(string: template) { NSWorkspace.shared.open(url) }
                hideLauncher(reactivate: false)
            } else {
                if let url = URL(string: "addressbook://\(uid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? uid)") {
                    NSWorkspace.shared.open(url)
                } else if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.AddressBook") {
                    NSWorkspace.shared.open(app)
                }
                hideLauncher(reactivate: false)
            }
        case "musicplay":
            hideLauncher(reactivate: false)
            Task.detached { _ = MusicService.playSearch(item.payload) }
        case "musicplayer":
            hideLauncher(reactivate: false)
            showMusicPlayer()
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
        if old.contactsEnabled != preferences.contactsEnabled { reloadContacts() }
        if !preferences.fileBufferEnabled { fileBuffer = []; fileBufferLastUsed = nil }
        if old.safariBookmarks != preferences.safariBookmarks || old.chromeBookmarks != preferences.chromeBookmarks { reloadLinks() }
    }

    func workflowsChanged() {
        scheduleSave()
        applyHotkeys()
        if selectedWorkflow == nil { selectedWorkflow = workflows.first?.id }
    }

    private func openInSourceBrowser(_ url: URL, linkID: String) {
        let bundle = linkID.lowercased().contains("chrome") ? "com.google.Chrome" : "com.apple.Safari"
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else {
            NSWorkspace.shared.open(url)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: configuration)
    }

    private func noteURLHistory(_ url: String) {
        preferences.urlHistory.removeAll { $0 == url }
        preferences.urlHistory.insert(url, at: 0)
        if preferences.urlHistory.count > 100 { preferences.urlHistory.removeLast(preferences.urlHistory.count - 100) }
        scheduleSave()
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
        if let window = preferencesWindow() {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            // The policy change and activation can race when the app was idle;
            // re-assert once the window is on screen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self else { return }
                NSApp.activate(ignoringOtherApps: true)
                self.preferencesWindow()?.makeKeyAndOrderFront(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                guard let self else { return }
                NSApp.activate(ignoringOtherApps: true)
                self.preferencesWindow()?.makeKeyAndOrderFront(nil)
            }
            return
        }
        AppRuntime.openPreferences?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.preferencesWindow()?.makeKeyAndOrderFront(nil)
        }
    }

    func notePreferencesWindow(_ window: NSWindow) {
        window.identifier = NSUserInterfaceItemIdentifier("preferences")
        NSApp.setActivationPolicy(.regular)
        if !AppRuntime.launchedAsLoginItem {
            activatePreferencesWindow(window)
        }
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

    private func activatePreferencesWindow(_ window: NSWindow) {
        for delay in [0.05, 0.3, 0.8, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak window] in
                guard let window, window.isVisible, !NSApp.isActive else { return }
                NSApp.setActivationPolicy(.regular)
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
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
        let policy: NSApplication.ActivationPolicy = showDock ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        // Changing policy drops Carbon hot keys registered on the old target.
        applyHotkeys()
    }

    private var leavingDock = false

    /// Leave the Dock without exiting. The launcher hotkey keeps working.
    func leaveDock() {
        guard !leavingDock else { return }
        leavingDock = true
        for window in NSApp.windows where !(window is NSPanel) && (window.identifier?.rawValue == "preferences" || window.title.contains("Preferences")) {
            window.close()
        }
        NSApp.setActivationPolicy(.accessory)
        applyHotkeys()
        leavingDock = false
    }

    func quit() {
        if preferences.clipboardClearOnQuit {
            clips = []
            save()
        }
        AppRuntime.explicitQuit = true
        NSApp.terminate(nil)
    }

    func handleRemote(_ target: String) -> String {
        record(category: "remote")
        let parts = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = String(parts.first ?? "/")
        let query = parts.count > 1 ? String(parts[1]) : ""
        let params = queryItems(query)
        let supplied = params["token"] ?? ""
        guard secureTokenEquals(supplied, preferences.remoteToken) else {
            return "<p>Token required. Add ?token= from Jfred Preferences → Remote.</p>"
        }
        if path == "/run" {
            let id = params["id"] ?? ""
            performSystem(id)
            return "<p>Ran \(escapeHTML(id)). <a href=\"/?token=\(preferences.remoteToken)\">Back</a></p>"
        }
        if path == "/open" {
            let value = params["path"] ?? ""
            if let url = URL(string: value), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                NSWorkspace.shared.open(url)
            } else if value.hasPrefix("/") {
                NSWorkspace.shared.open(URL(fileURLWithPath: value))
            }
            return "<p>Opened. <a href=\"/?token=\(preferences.remoteToken)\">Back</a></p>"
        }
        let q = params["q"] ?? ""
        var body = """
        <!doctype html><meta charset="utf-8"><meta name="referrer" content="no-referrer"><title>Jfred Remote</title>
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
            body += "<h2>\(escapeHTML(remoteCategory.title))</h2><ul>"
            switch remoteCategory {
            case .system:
                for command in SystemCommand.all {
                    body += "<li><a href=\"/run?token=\(preferences.remoteToken)&id=\(escapeHTML(command.id))\">\(escapeHTML(command.title))</a></li>"
                }
            case .applications:
                for app in apps.prefix(40) {
                    let value = app.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    body += "<li><a href=\"/open?token=\(preferences.remoteToken)&path=\(value)\">\(escapeHTML(app.name))</a></li>"
                }
            case .preferences:
                for setting in SettingsCatalog.all {
                    let value = setting.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    body += "<li><a href=\"/open?token=\(preferences.remoteToken)&path=\(value)\">\(escapeHTML(setting.name))</a></li>"
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
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func secureTokenEquals(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        guard x.count == y.count else { return false }
        var diff: UInt8 = 0
        for i in x.indices { diff |= x[i] ^ y[i] }
        return diff == 0
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

    func workflowDirectory(_ workflow: Workflow) -> URL? {
        guard let group = workflow.builtin else { return nil }
        return scriptCatalog.nodes.values
            .first { $0.group == group }
            .map { URL(fileURLWithPath: $0.cwd, isDirectory: true) }
    }

    func importWorkflow(at url: URL) {
        guard let bundle = JfredStore.importWorkflow(at: url) else {
            importNote = "Could not import \(url.lastPathComponent)."
            return
        }
        let catalog = JfredStore.catalog()
        scriptCatalog = catalog
        JfredStore.syncWorkflows(self, catalog.workflows)
        if let imported = workflows.first(where: { $0.builtin == bundle }) {
            selectedWorkflow = imported.id
        }
        section = .workflows
        showPreferences()
        importNote = "Imported \(url.lastPathComponent)."
    }

    func moveWorkflowAction(from source: Int, to target: Int) {
        guard let id = editingWorkflowID ?? selectedWorkflow,
              let wf = workflows.firstIndex(where: { $0.id == id }),
              workflows[wf].actions.indices.contains(source),
              workflows[wf].actions.indices.contains(target),
              source != target else { return }
        let item = workflows[wf].actions.remove(at: source)
        workflows[wf].actions.insert(item, at: target)
        workflowSelection = target
    }

    func runWorkflowDebug(_ id: UUID) {
        guard let workflow = workflows.first(where: { $0.id == id }) else { return }
        let resuming = debugPaused && debugWorkflowID == id
        if !resuming {
            debuggerVisible = true
            debugLines = ["Running \(workflow.name) with query ‘\(debugQuery)’"]
            debugCursor = 0
            debugWorkflowID = id
        }
        debugPaused = false
        let query = debugQuery
        let actions = workflow.actions
        let start = resuming ? debugCursor : 0
        let resumeFrom = start
        Task {
            var index = start
            while index < actions.count {
                if self.debugBreakpoints.contains(index) && !(resuming && index == resumeFrom) {
                    await MainActor.run {
                        self.debugCursor = index
                        self.debugPaused = true
                        self.debugLines.append("Paused at breakpoint before action \(index + 1).")
                    }
                    return
                }
                await MainActor.run { self.debugCursor = index }
                await executeDebugAction(actions[index], query: query, index: index)
                index += 1
                await MainActor.run { self.debugCursor = index }
            }
            await MainActor.run {
                self.debugCursor = actions.count
                self.debugPaused = false
                self.debugLines.append("Finished.")
            }
        }
    }

    func setBreakpoint(_ index: Int, _ enabled: Bool) {
        if enabled { debugBreakpoints.insert(index) } else { debugBreakpoints.remove(index) }
    }

    func stepWorkflowDebug(_ id: UUID) {
        guard let workflow = workflows.first(where: { $0.id == id }) else { return }
        if debugWorkflowID != id {
            debugWorkflowID = id
            debugCursor = 0
            debugLines = ["Stepping \(workflow.name) with query ‘\(debugQuery)’"]
        }
        debuggerVisible = true
        guard debugCursor < workflow.actions.count else {
            debugLines.append("Finished.")
            return
        }
        let index = debugCursor
        let action = workflow.actions[index]
        let query = debugQuery
        Task {
            await executeDebugAction(action, query: query, index: index)
            await MainActor.run {
                self.debugCursor = index + 1
                self.debugPaused = false
                if self.debugCursor >= workflow.actions.count { self.debugLines.append("Finished.") }
            }
        }
    }

    private func executeDebugAction(_ action: WorkflowAction, query: String, index: Int) async {
        let value = action.value.replacingOccurrences(of: "{query}", with: query)
        await MainActor.run { self.debugLines.append("\(index + 1). \(action.kind.rawValue): \(value)") }
        switch action.kind {
        case .openURL:
            if let url = URL(string: value) { await MainActor.run { NSWorkspace.shared.open(url) } }
        case .openApp:
            await MainActor.run {
                let url = value.hasPrefix("/") ? URL(fileURLWithPath: value) : URL(fileURLWithPath: "/Applications/\(value).app")
                NSWorkspace.shared.open(url)
            }
        case .copy:
            await MainActor.run { self.writeClipboard(value) }
        case .largeType:
            await MainActor.run { self.showLarge(value) }
        case .terminal:
            await MainActor.run { self.runInTerminal(value) }
        case .shell:
            let output = await Task.detached { Shell.run("/bin/zsh", ["-lc", value], timeout: 12) }.value
            await MainActor.run { self.debugLines.append("   ↳ \(output.isEmpty ? "(no output)" : String(output.prefix(300)))") }
        case .appleScript:
            let output = await Task.detached { Shell.osascript(value, timeout: 12) }.value
            await MainActor.run { self.debugLines.append("   ↳ \(output.isEmpty ? "(no output)" : String(output.prefix(300)))") }
        }
    }

    func reloadWorkflowsFromAlfred() {
        guard let catalog = JfredStore.reloadCatalog() else { return }
        scriptCatalog = catalog
        JfredStore.syncWorkflows(self, catalog.workflows)
    }

    func importAlfredLibrary() {
        let count = JfredStore.importAllFromAlfred()
        let catalog = JfredStore.catalog()
        scriptCatalog = catalog
        JfredStore.syncWorkflows(self, catalog.workflows)
        importNote = "Imported \(count) workflows from Alfred."
        section = .workflows
        showPreferences()
    }

    func duplicateWorkflow(_ id: UUID) {
        guard let index = workflows.firstIndex(where: { $0.id == id }) else { return }
        var copy = workflows[index]
        copy.id = UUID()
        copy.name += " Copy"
        copy.builtin = nil
        copy.hotkey = nil
        copy.actions = copy.actions.map { WorkflowAction(kind: $0.kind, value: $0.value) }
        workflows.insert(copy, at: index + 1)
        selectedWorkflow = copy.id
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
            forcedResults: forced,
            spotlight: { term, tags in
                let escaped = term.replacingOccurrences(of: "'", with: "\\'")
                let predicate = tags
                    ? "kMDItemUserTags == '\(escaped)'cd"
                    : "kMDItemTextContent == '*\(escaped)*'cd"
                let output = Shell.run("/usr/bin/mdfind", [predicate], timeout: 3)
                return output.split(separator: "\n").prefix(40).map { line in
                    let path = String(line)
                    return AppRecord(id: path, name: (path as NSString).lastPathComponent, path: path)
                }
            }
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

    private func pasteClipboardItem(_ clip: ClipItem) {
        if preferences.clipboardMoveToTopOnUse, let index = clips.firstIndex(where: { $0.id == clip.id }), index > 0 {
            let item = clips.remove(at: index)
            clips.insert(item, at: 0)
            scheduleSave()
        }
        let board = NSPasteboard.general
        board.clearContents()
        switch clip.kind {
        case "image":
            if let path = clip.imageFile, let image = NSImage(contentsOfFile: path) {
                board.writeObjects([image])
            }
        case "file":
            if let paths = clip.filePaths {
                board.writeObjects(paths.map { URL(fileURLWithPath: $0) as NSURL })
            }
        default:
            board.setString(clip.text, forType: .string)
        }
        hideLauncher(reactivate: true)
        guard preferences.clipboardAutoPaste else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            postKey(9, flags: .maskCommand)
        }
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
        if preferences.systemDisabled.contains(id) { return }
        if id.hasPrefix("volume:") {
            guard let value = Int(id.dropFirst("volume:".count)), (0...100).contains(value) else { return }
            _ = Shell.osascript("set volume output volume \(value)")
            return
        }
        if preferences.systemConfirm.contains(id) {
            let alert = NSAlert()
            alert.messageText = "Run this system command?"
            alert.informativeText = "This action may interrupt what you are doing."
            alert.addButton(withTitle: "Continue")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        switch id {
        case "sleep": _ = Shell.osascript("tell application \"System Events\" to sleep")
        case "restart": _ = Shell.osascript("tell application \"System Events\" to restart")
        case "shutdown": _ = Shell.osascript("tell application \"System Events\" to shut down")
        case "logout": _ = Shell.osascript("tell application \"System Events\" to log out")
        case "lock": _ = Shell.osascript("tell application \"System Events\" to keystroke \"q\" using {command down, control down}")
        case "screensaver": _ = Shell.run("/usr/bin/open", ["-a", "ScreenSaverEngine"])
        case "emptetrash": _ = Shell.osascript("tell application \"Finder\" to empty trash")
        case "trash": _ = Shell.run("/usr/bin/open", [NSHomeDirectory() + "/.Trash"])
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
        case "musicplaypause": _ = MusicService.playPause()
        case "musicnext": _ = MusicService.next()
        case "musicprevious": _ = MusicService.previous()
        case "musiccurrent":
            let track = MusicService.currentTrack()
            debugLine = track.isEmpty ? "Music is not playing" : track
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
        let escaped = command
            .replacingOccurrences(of: "\0", with: "")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
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
        let selectionHotkeyOK = HotkeyCenter.shared.register(id: 2, keyCode: 42, modifiers: Hotkey(keyCode: 42, modifiers: Hotkey.option | Hotkey.command).carbonModifiers) { [weak self] in
            Task { @MainActor in self?.showSelectionActions() }
        }
        selectionHotkeyWarning = selectionHotkeyOK ? "" : "⌥⌘\\ is already used by another app. Pick a different Universal Actions shortcut or free it up."
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
        SnippetExpander.shared.update(
            enabled: preferences.snippetsEnabled,
            snippets: snippets,
            wordBased: preferences.snippetWordBased,
            playSound: preferences.snippetExpandPlaySound,
            restoreClipboard: preferences.snippetExpandRestoreClipboard
        )
    }

    func refreshMusicTrack() {
        Task.detached {
            let track = MusicService.currentTrack()
            await MainActor.run { self.musicTrack = track }
        }
    }

    func refreshMusicPanel() {
        Task.detached {
            let info = MusicService.info()
            await MainActor.run {
                self.musicNowTitle = info.title
                self.musicNowArtist = info.artist
                self.musicNowPlaying = info.playing
                self.musicTrack = info.title.isEmpty ? "" : "\(info.title) — \(info.artist)"
            }
        }
    }

    func searchMusic() {
        let query = musicSearch
        Task.detached {
            let tracks = MusicService.searchTracks(query)
            await MainActor.run { self.musicTracks = tracks }
        }
    }

    func playMusic(_ track: MusicService.Track) {
        Task.detached {
            _ = MusicService.playSearch(track.title)
            try? await Task.sleep(nanoseconds: 350_000_000)
            let info = MusicService.info()
            await MainActor.run {
                self.musicNowTitle = info.title
                self.musicNowArtist = info.artist
                self.musicNowPlaying = info.playing
                self.musicTrack = info.title.isEmpty ? "" : "\(info.title) — \(info.artist)"
            }
        }
    }

    func showMusicPlayer() {
        refreshMusicPanel()
        launcher?.showMusicPlayer()
    }

    func showSelectionActions() {
        if let text = Accessibility.selectedText() {
            let title = String(text.split(separator: "\n").first ?? Substring(text)).trimmingCharacters(in: .whitespaces)
            presentTransient(SearchResult(
                id: "selection:text", title: title.isEmpty ? "Selected Text" : String(title.prefix(120)),
                subtitle: "Universal Action", icon: "symbol:text.cursor", kind: "text",
                payload: text, category: "action", score: 2
            ))
            return
        }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else { return }
        let files = Accessibility.finderSelection()
        guard let first = files.first else { return }
        let title = (first as NSString).lastPathComponent
        presentTransient(SearchResult(
            id: "selection:file:\(first)", title: title, subtitle: files.count > 1 ? "\(files.count) selected files" : first,
            icon: "file:\(first)", kind: "file", payload: first, category: "action", score: 2
        ))
    }

    private func presentTransient(_ item: SearchResult) {
        previousApp = NSWorkspace.shared.frontmostApplication
        if previousApp?.bundleIdentifier == Bundle.main.bundleIdentifier { previousApp = nil }
        transientItem = item
        query = ""
        results = [item]
        selection = 0
        launcherVisible = true
        focusToken += 1
        SnippetExpander.shared.setSuspended(true)
        launcher?.show()
        launcher?.layout()
        showActions()
    }

    func reloadContacts() {
        guard preferences.contactsEnabled else {
            if !contacts.isEmpty { contacts = [] }
            return
        }
        Task.detached {
            let list = await ContactsIndex.load()
            await MainActor.run {
                guard self.preferences.contactsEnabled else { return }
                self.contacts = list
                self.scheduleSave()
            }
        }
    }

    func requestContactsAccess() {
        Task.detached {
            let list = await ContactsIndex.load(requestAccess: true)
            await MainActor.run {
                self.contacts = list
                self.scheduleSave()
            }
        }
    }

    func regenerateRemoteToken() {
        preferences.remoteToken = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        scheduleSave()
        applyRemote()
    }

    func applyRemote() {
        if preferences.remoteToken.count < 24 {
            preferences.remoteToken = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            scheduleSave()
        }
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

    private var clipboardStableChange = -1

    /// Password managers and system credential UIs intentionally copy secrets;
    /// never add those to the history even when an app forgets to mark the
    /// pasteboard as concealed.
    private let privateClipboardApps: Set<String> = [
        "1Password", "1Password 7", "Keychain Access", "Passwords", "Wallet",
        "SecurityAgent", "System Settings", "System Preferences",
    ]

    private func pollClipboard() {
        let board = NSPasteboard.general
        guard preferences.clipboardEnabled, board.changeCount != clipChange else { return }
        // Wait for one extra poll so transient intermediate pasteboard states
        // (apps writing then rewriting, drag sessions) are not captured.
        if clipboardStableChange != board.changeCount {
            clipboardStableChange = board.changeCount
            return
        }
        clipChange = board.changeCount
        pruneClipboard()
        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        if privateClipboardApps.contains(sourceApp) { return }
        if preferences.clipboardIgnoreApps.contains(where: { $0.caseInsensitiveCompare(sourceApp) == .orderedSame }) { return }
        let types = Set(board.types ?? [])
        if types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")) { return }
        if preferences.clipboardIgnoreConcealed,
           types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) { return }
        if preferences.clipboardIgnoreAutoGenerated,
           types.contains(NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")) { return }
        let remote = types.contains(NSPasteboard.PasteboardType("com.apple.is-remote-clipboard"))
        if preferences.clipboardKeepFiles,
           !(remote && preferences.clipboardIgnoreUniversalFiles),
           let urls = clipboardFileURLs(board), !urls.isEmpty {
            let paths = urls.map(\.path)
            if clips.first?.filePaths == paths { return }
            clips.insert(ClipItem(text: urls.map(\.lastPathComponent).joined(separator: ", "), date: Date(), kind: "file", filePaths: paths), at: 0)
            if clips.count > preferences.clipboardLimit { clips = Array(clips.prefix(preferences.clipboardLimit)) }
            scheduleSave()
            return
        }
        if preferences.clipboardKeepImages,
           !(remote && preferences.clipboardIgnoreUniversalText),
           let path = saveClipboardImage(board) {
            if clips.first?.imageFile == path { return }
            clips.insert(ClipItem(text: "Image", date: Date(), kind: "image", imageFile: path), at: 0)
            if clips.count > preferences.clipboardLimit { clips = Array(clips.prefix(preferences.clipboardLimit)) }
            scheduleSave()
            return
        }
        guard preferences.clipboardKeepText,
              !(remote && preferences.clipboardIgnoreUniversalText) else { return }
        guard let text = board.string(forType: .string), !text.isEmpty else { return }
        guard text.count <= max(4_096, preferences.clipboardMaxSize) else { return }
        if clips.first?.text == text { return }
        clips.insert(ClipItem(text: text, date: Date()), at: 0)
        if clips.count > preferences.clipboardLimit { clips = Array(clips.prefix(preferences.clipboardLimit)) }
        scheduleSave()
    }

    private func clipboardFileURLs(_ board: NSPasteboard) -> [URL]? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return board.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
    }

    private func saveClipboardImage(_ board: NSPasteboard) -> String? {
        guard let data = board.data(forType: .png) ?? board.data(forType: .tiff) else { return nil }
        let dir = supportDirectory().appendingPathComponent("ClipImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let url = dir.appendingPathComponent("\(UUID().uuidString).png")
        if let rep = NSBitmapImageRep(data: data), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        } else if let image = NSImage(data: data), let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        } else {
            return nil
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return url.path
    }

    private var clipRetentionInterval: TimeInterval? {
        switch preferences.clipboardRetention {
        case "1 day": return 86_400
        case "1 week": return 7 * 86_400
        case "1 month": return 30 * 86_400
        case "3 months": return 90 * 86_400
        case "1 year": return 365 * 86_400
        default: return nil
        }
    }

    private func pruneClipboard() {
        guard let interval = clipRetentionInterval, !clips.isEmpty else { return }
        let cutoff = Date().addingTimeInterval(-interval)
        clips.removeAll { $0.date < cutoff }
    }

    func clearClipboardHistory() {
        clips = []
        scheduleSave()
    }

    func clearUsageData() {
        usage = []
        scheduleSave()
    }

    func clearClipboardHistory(lastMinutes minutes: Int) {
        let cutoff = Date().addingTimeInterval(-TimeInterval(minutes * 60))
        clips.removeAll { $0.date >= cutoff }
        scheduleSave()
    }

    private func supportDirectory() -> URL {
        let url = SupportPaths.directory(syncFolder: preferences.syncFolder)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    private func load() {
        hardenSupportFolder()
        let url = supportDirectory().appendingPathComponent("state.json")
        guard let data = try? Data(contentsOf: url), let state = try? JSONDecoder().decode(DiskState.self, from: data) else {
            preferences = Preferences()
            workflows = Seed.workflows()
            snippets = Seed.snippets()
            finishJfredStore()
            return
        }
        preferences = state.preferences
        let legacyBuiltins: Set<String> = ["dev", "epoch", "unit", "kill", "tabs", "profiles", "windows", "ui"]
        workflows = state.workflows.filter { workflow in
            workflow.builtin.map { !legacyBuiltins.contains($0) } ?? true
        }
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
            let catalog = JfredStore.catalog()
            scriptCatalog = catalog
            JfredStore.syncWorkflows(self, catalog.workflows)
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

    private func hardenSupportFolder() {
        let dir = supportDirectory()
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        let state = dir.appendingPathComponent("state.json")
        if FileManager.default.fileExists(atPath: state.path) {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: state.path)
        }
        let images = dir.appendingPathComponent("ClipImages", isDirectory: true)
        if let files = try? FileManager.default.contentsOfDirectory(at: images, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            }
        }
    }

    func saveNewsletterEmail() {
        preferences.newsletterEmail = preferences.newsletterEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        scheduleSave()
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
    @objc private func statusQuit() { quit() }
}

enum PrefSection: String, CaseIterable, Identifiable {
    case general, features, workflows, appearance, remote, advanced, powerpack, usage, help, update
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "General"
        case .features: "Features"
        case .workflows: "Workflows"
        case .appearance: "Appearance"
        case .remote: "Remote"
        case .advanced: "Advanced"
        case .powerpack: "Powerpack"
        case .usage: "Usage"
        case .help: "Help"
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
        case .powerpack: "bolt.fill"
        case .usage: "chart.xyaxis.line"
        case .help: "lifepreserver"
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
    case defaultResults, fileSearch, universalActions, webSearch, bookmarks, clipboard, snippets, calculator, dictionary, contacts, music, onePassword, system, terminal, largeType, previews
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
        case .contacts: "Contacts"
        case .music: "Music"
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
        case .contacts: "Viewer, Emailing"
        case .music: "Mini Player"
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
        case .contacts: "person.crop.circle"
        case .music: "music.note"
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
            PreferenceHit(id: "theme", title: "Appearance themes", detail: "Alfred themes, custom themes and live preview", section: .appearance, feature: nil),
            PreferenceHit(id: "remote", title: "Remote server", detail: "Local command page, QR pairing and token rotation", section: .remote, feature: nil),
            PreferenceHit(id: "theme-files", title: "Import or export themes", detail: "Appearance .alfredappearance files", section: .appearance, feature: nil),
            PreferenceHit(id: "clipboard-ignore", title: "Clipboard Ignore Apps", detail: "Privacy and excluded applications", section: .features, feature: .clipboard),
            PreferenceHit(id: "snippet-expansion", title: "Auto Expansion Options", detail: "Snippets, sound and clipboard restore", section: .features, feature: .snippets),
            PreferenceHit(id: "workflow-debugger", title: "Workflow Debugger", detail: "Test query, Run, Step and breakpoints", section: .workflows, feature: nil),
            PreferenceHit(id: "universal-actions", title: "Universal Actions", detail: "Selection hotkey and action ordering", section: .features, feature: .universalActions),
            PreferenceHit(id: "help", title: "Help and diagnostics", detail: "Troubleshooting, permissions, Copy Diagnostics", section: .help, feature: nil),
            PreferenceHit(id: "powerpack", title: "Powerpack features", detail: "Locally included feature set", section: .powerpack, feature: nil),
        ]
        for feature in FeatureID.allCases {
            rows.append(PreferenceHit(id: feature.id, title: feature.title, detail: feature.subtitle, section: .features, feature: feature))
        }
        return rows
    }()
}
