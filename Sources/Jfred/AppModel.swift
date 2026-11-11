import AppKit
import JfredCore
import Foundation
import ServiceManagement
import UniformTypeIdentifiers

enum AppRuntime {
    @MainActor static var model: AppModel?
    @MainActor static var openPreferences: (() -> Void)?
    /// Quit Jfred, the status menu, and killing this process. Dock Quit stays resident.
    @MainActor static var explicitQuit = false
    /// macOS is logging out, restarting or shutting down; let it quit Jfred.
    @MainActor static var systemPoweringOff = false
    /// True when macOS started Jfred as a login item; don't steal focus then.
    @MainActor static var launchedAsLoginItem = false
    /// Offscreen Preferences render used for visual checks. Never installs
    /// hotkeys or loads the user's saved state.
    @MainActor static var renderPreferencesOnly = false
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
    // Saved state. Each change marks the file it lives in, so a save writes
    // only the files that changed: state.json, clips.json or usage.json.
    var preferences = Preferences() { didSet { unsavedSections.insert(.main) } }
    var workflows: [Workflow] = [] { didSet { unsavedSections.insert(.main) } }
    var snippets: [Snippet] = [] { didSet { unsavedSections.insert(.main) } }
    var clips: [ClipItem] = [] { didSet { unsavedSections.insert(.clips) } }
    var usage: [UsageEvent] = [] { didSet { unsavedSections.insert(.usage) } }
    var knowledge: [String: String] = [:] { didSet { unsavedSections.insert(.main) } }
    var selections: [String: SelectionStat] = [:] { didSet { unsavedSections.insert(.main) } }
    var apps: [AppRecord] = []
    var links: [LinkRecord] = []
    var actionsTab = "General"
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
    var clipboardHotkeyWarning = ""
    var actionPanelVisible = false
    var actionIndex = 0
    var launcherActions: [LauncherAction] = []
    private var actionRoot: [LauncherAction] = []
    private var actionDrilled = false
    var opItems: [AppRecord] = []
    /// Prepared match keys for apps, links, snippets and the other searchable
    /// records. Refreshed before each search; only changed sections rebuild.
    @ObservationIgnored private var searchIndex = SearchIndex()
    private(set) var updatePhase: UpdatePhase = .idle
    private(set) var pendingUpdate: UpdateRelease?
    private(set) var updateNotes = ""
    private var updateCatalog = UpdateCatalog(releases: [], publishedCount: 0)
    private var updateCatalogReady = false
    private var updateGeneration = 0

    var updateReady: Bool {
        switch updatePhase {
        case .available, .downloading, .installing: return true
        case .failed: return pendingUpdate != nil
        default: return false
        }
    }

    var updateStatusLine: String {
        switch updatePhase {
        case .idle: "not checked"
        case .checking: "checking"
        case .current: "up to date"
        case .available: "available \(pendingUpdate?.version ?? "")"
        case .downloading: "downloading"
        case .installing: "installing"
        case .failed(let message): "failed: \(message)"
        }
    }

    var query = ""
    var results: [SearchResult] = []
    var selection = 0
    var launcherVisible = false
    var fileBuffer: [SearchResult] = []
    var hotkeyWarning = ""
    var hotkeyFieldFocused = false
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
    var section: PrefSection = PrefSection(rawValue: PreferencesSidebar.defaultSelection) ?? .general
    var feature: FeatureID = .defaultResults
    var selectedWorkflow: UUID?
    var focusToken = 0
    var featureSheet: FeatureSheet?
    var selectedScopePath: String?
    var workflowFilter = ""
    var editingWorkflowID: UUID?
    var workflowSnapshot: Workflow?
    var workflowIsNew = false
    var showTemplates = false
    var selectedWorkflowObject: UUID?
    var workflowDebugState: WorkflowRunState?
    var debugLoggedCount = 0
    var debugAppliedEffects = 0
    var workflowDragObjectID: UUID?
    var workflowDragStart: WorkflowPoint?
    var workflowPaletteVisible = true
    var workflowPaletteFilter = ""
    var workflowPaletteExpanded: Set<String> = ["Favourites"]
    var workflowConfigPresented = false
    var workflowConfigShowsWorkflow = false
    var workflowConfigEditsMetadata = false
    var workflowConfigSnapshot: Workflow?
    var importNote = ""
    var workflowImportStatus = ""
    var hideDisabledWorkflows = false
    var showStatusItem: Bool {
        get { knowledge["statusItem"] != "hidden" }
        set {
            knowledge["statusItem"] = newValue ? "shown" : "hidden"
            refreshStatusItem()
            scheduleSave()
        }
    }

    private var generation = 0
    /// The Spotlight file lookup for the current query, if one is running.
    @ObservationIgnored private var fileSearchTask: Task<Void, Never>?
    /// Script Filter runs: the one in flight, a query waiting for it, and the
    /// delay before the newest query. At most one script runs at a time.
    @ObservationIgnored private var scriptQueue = ScriptFilterQueue<WorkflowMatch>()
    @ObservationIgnored private var scriptRuns: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var scriptDelay: Task<Void, Never>?
    @ObservationIgnored private var typingCadence = TypingCadence()
    /// The query last counted as a keystroke by `typingCadence`.
    @ObservationIgnored private var cadenceQuery = ""
    /// Short-lived Script Filter results keyed by "workflowID|inputID|argument".
    private var scriptFilterCache: [String: (date: Date, rows: [SearchResult])] = [:]
    /// "Searching…" or "Running…" while a file search or Script Filter is
    /// pending; the launcher shows a spinner in the query field.
    private(set) var searchingSubtitle: String?
    /// Query string last written into `results`. Selection resets only when it changes.
    private var renderedQuery = ""
    private var historyCursor: Int?
    private var fromHistory = false
    private var clipChange = 0
    private var fileBufferLastUsed: Date?
    private var workflowHotkeyIDs: [UInt32] = []
    private var previousApp: NSRunningApplication?
    /// Bumped whenever the launcher is shown, hidden or given a transient
    /// item, so work that finishes later can tell the user has moved on.
    @ObservationIgnored private var launcherEpoch = 0
    @ObservationIgnored private var saveWork: DispatchWorkItem?
    /// Sections changed since the last save.
    @ObservationIgnored private var unsavedSections: StateSections = []
    /// Encodes and writes snapshots off the main thread.
    @ObservationIgnored private let stateWriter = StateWriter()
    /// Where the last save went; a new support folder gets every file.
    @ObservationIgnored private var lastSaveDirectory: URL?
    var launcher: LauncherController?
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
        reindex()
        reloadLinks()
        if preferences.onePasswordEnabled { reloadOnePassword() }
        syncActivationPolicy()
        IndexWatch.shared.start(preferences: preferences) { [weak self] in
            self?.reindex()
        }
        clipChange = NSPasteboard.general.changeCount
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollClipboard()
                self?.pruneFileBuffer()
            }
        }
        if !suppressPrompts {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                self?.checkForUpdates(userInitiated: false)
            }
        }
    }

    func scheduleSearch() {
        generation += 1
        let token = generation
        if query != cadenceQuery {
            cadenceQuery = query
            typingCadence.keystroke(at: ProcessInfo.processInfo.systemUptime)
        }
        cancelFileSearch()
        if let browser = fileBrowserResults(query) {
            stopScriptFilter()
            publishResults(browser)
            return
        }
        if transientItem != nil {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                stopScriptFilter()
                return
            }
            transientItem = nil
        }
        if fromHistory {
            fromHistory = false
        } else {
            historyCursor = nil
        }
        let raw = query
        let disabledBuiltins = Set(workflows.compactMap { workflow -> String? in
            guard let builtin = workflow.builtin, !workflow.enabled else { return nil }
            return builtin
        })
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var context = makeContext(files: [], definition: nil, forced: nil)
        searchIndex.refresh(for: context)
        context.index = searchIndex
        let useWorkflows = !raw.hasPrefix(" ") && !trimmed.hasPrefix(">")
        if useWorkflows, let match = WorkflowRuntime.match(in: workflows, query: trimmed, disabledBuiltins: disabledBuiltins) {
            if match.input.kind == .scriptFilter {
                scheduleScriptFilter(match)
                return
            }
            stopScriptFilter()
            if match.input.kind == .listFilter {
                runListFilter(match, token: token)
                return
            }
            if let row = WorkflowRuntime.directRow(for: match) {
                publishResults([row])
                return
            }
        }
        stopScriptFilter()

        guard let fileQuery = Search.fileQuery(raw: raw, preferences: context.preferences) else {
            publishResults(Search.results(for: raw, context: context))
            guard let word = Search.wantsDefinition(raw: raw), context.preferences.dictionaryEnabled else { return }
            let job = Task.detached { DictionaryLookup.define(word) }
            Task {
                let definition = await job.value
                guard token == self.generation, let definition else { return }
                var enriched = context
                enriched.definition = definition
                self.publishResults(Search.results(for: raw, context: enriched))
            }
            return
        }

        if fileQuery.text.isEmpty {
            // Only the prefix or keyword so far: show the hint row.
            publishResults(Search.results(for: raw, context: context))
            return
        }
        // Keep existing rows while the file lookup runs. Only show a
        // placeholder when there is nothing on screen yet.
        if results.isEmpty {
            publishResults([statusRow(id: "search:pending", title: "Searching…", subtitle: trimmed, icon: "symbol:magnifyingglass", category: "navigation")])
        }
        let preferences = context.preferences
        // A one- or two-letter name prefix is slow in Spotlight until cached.
        // Wait briefly so a prefix typed on the way to a longer query never
        // starts one.
        let delay = fileQuery.launchDelay
        fileSearchTask = Task {
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
                guard token == self.generation, !Task.isCancelled else { return }
            }
            // A newer keystroke stops this query inside SpotlightSearch and
            // makes `search` return nil.
            guard let hits = await SpotlightSearch.shared.search(fileQuery, preferences: preferences) else { return }
            guard token == self.generation, !Task.isCancelled else { return }
            var found = context
            found.files = hits
            let working = found
            let rows = await Task.detached { Search.results(for: raw, context: working) }.value
            guard token == self.generation, !Task.isCancelled else { return }
            self.fileSearchTask = nil
            self.refreshSearching()
            self.publishResults(rows)
        }
        refreshSearching()
    }

    /// Stops a running Spotlight file query whose rows nobody will see.
    private func cancelFileSearch() {
        guard let task = fileSearchTask else { return }
        task.cancel()
        fileSearchTask = nil
        SpotlightSearch.shared.cancel()
        refreshSearching()
    }

    /// "Searching…" while a Spotlight query runs or waits to start, "Running…"
    /// while a Script Filter runs or waits; nil when nothing is pending.
    private func refreshSearching() {
        let subtitle: String?
        if scriptQueue.isBusy {
            subtitle = "Running…"
        } else if fileSearchTask != nil {
            subtitle = "Searching…"
        } else {
            subtitle = nil
        }
        if searchingSubtitle != subtitle { searchingSubtitle = subtitle }
    }

    private static func scriptFilterCacheKey(_ match: WorkflowMatch) -> String {
        "\(match.workflow.id.uuidString)|\(match.input.id.uuidString)|\(match.invocation.argument)"
    }

    private func cachedScriptFilterRows(_ match: WorkflowMatch) -> [SearchResult]? {
        guard let cached = scriptFilterCache[Self.scriptFilterCacheKey(match)],
              Date().timeIntervalSince(cached.date) < 8 else { return nil }
        return cached.rows
    }

    private func cacheScriptFilterRows(_ rows: [SearchResult], for match: WorkflowMatch) {
        scriptFilterCache[Self.scriptFilterCacheKey(match)] = (Date(), rows)
        if scriptFilterCache.count > 40 {
            let trimmed = scriptFilterCache.sorted { $0.value.date > $1.value.date }.prefix(24)
            scriptFilterCache = Dictionary(uniqueKeysWithValues: trimmed.map { ($0.key, $0.value) })
        }
    }

    /// Queues a Script Filter run for the current query, following the
    /// object's Run Behaviour (see `ScriptFilterRunBehaviour`).
    private func scheduleScriptFilter(_ match: WorkflowMatch) {
        let request = ScriptFilterQueue<WorkflowMatch>.Request(
            filter: "\(match.workflow.id.uuidString)|\(match.input.id.uuidString)",
            argument: match.invocation.argument,
            behaviour: ScriptFilterRunBehaviour(config: match.input.config),
            payload: match
        )
        if let cached = cachedScriptFilterRows(match) {
            performScriptCommands(scriptQueue.answer(request))
            publishResults(cached)
            refreshSearching()
            return
        }
        // Keep the previous list visible; the busy indicator shows the run.
        if results.isEmpty {
            publishResults([statusRow(id: "run:pending", title: match.invocation.keyword, subtitle: "Running…", icon: match.workflow.resolvedIcon(objectUID: match.input.alfredUID).resource, category: "action")])
        }
        performScriptCommands(scriptQueue.submit(request, automaticDelay: typingCadence.delay))
        refreshSearching()
    }

    private func performScriptCommands(_ commands: [ScriptFilterQueue<WorkflowMatch>.Command]) {
        for command in commands {
            switch command {
            case .terminate(let id):
                // Cancelling the task terminates the script's processes.
                scriptRuns.removeValue(forKey: id)?.cancel()
            case .wait(let seconds, let ticket):
                scriptDelay?.cancel()
                scriptDelay = nil
                if seconds <= 0 {
                    performScriptCommands(scriptQueue.fire(ticket: ticket))
                } else {
                    scriptDelay = Task { [weak self] in
                        try? await Task.sleep(for: .seconds(seconds))
                        guard !Task.isCancelled, let self else { return }
                        self.scriptDelay = nil
                        self.performScriptCommands(self.scriptQueue.fire(ticket: ticket))
                        self.refreshSearching()
                    }
                }
            case .launch(let id, let request):
                launchScriptFilter(id, match: request.payload)
            }
        }
    }

    private func launchScriptFilter(_ id: Int, match: WorkflowMatch) {
        scriptRuns[id] = Task { [weak self] in
            let rows = await Self.scriptFilterRows(match)
            guard let self, !Task.isCancelled, let rows else { return }
            self.finishScriptFilter(id, match: match, rows: rows)
        }
    }

    /// Runs the script and builds its rows off the main thread. Nil when the
    /// run was cancelled.
    nonisolated private static func scriptFilterRows(_ match: WorkflowMatch) async -> [SearchResult]? {
        let ran = await WorkflowRuntime.engine(for: match.workflow).results(for: match.invocation)
        if Task.isCancelled { return nil }
        let result = ran ?? WorkflowScriptFilterResult(items: [])
        if result.items.isEmpty {
            let icon = match.workflow.resolvedIcon(objectUID: match.input.alfredUID).resource
            return [SearchResult(id: "run:empty", title: "No matches", subtitle: match.invocation.keyword, icon: icon, kind: "text", payload: "", category: "action", score: 1)]
        }
        return WorkflowRuntime.rows(for: match, result: result)
    }

    private func finishScriptFilter(_ id: Int, match: WorkflowMatch, rows: [SearchResult]) {
        scriptRuns[id] = nil
        let (outcome, commands) = scriptQueue.finish(runID: id)
        switch outcome {
        case .current, .interim:
            cacheScriptFilterRows(rows, for: match)
            publishResults(rows)
        case .stale:
            cacheScriptFilterRows(rows, for: match)
        case .unknown:
            break
        }
        performScriptCommands(commands)
        refreshSearching()
    }

    /// Terminates the Script Filter run in flight and drops waiting queries.
    private func stopScriptFilter() {
        scriptDelay?.cancel()
        scriptDelay = nil
        performScriptCommands(scriptQueue.reset())
        for task in scriptRuns.values { task.cancel() }
        scriptRuns.removeAll()
        refreshSearching()
    }

    /// List Filters filter a fixed list; nothing to queue or terminate.
    private func runListFilter(_ match: WorkflowMatch, token: Int) {
        if let cached = cachedScriptFilterRows(match) {
            publishResults(cached)
            return
        }
        Task {
            guard let rows = await Self.scriptFilterRows(match), token == self.generation else { return }
            self.cacheScriptFilterRows(rows, for: match)
            self.publishResults(rows)
        }
    }

    private func statusRow(id: String, title: String, subtitle: String, icon: String, category: String) -> SearchResult {
        SearchResult(id: id, title: title, subtitle: subtitle, icon: icon, kind: "text", payload: "", category: category, score: 1)
    }

    private func fileBrowserResults(_ raw: String) -> [SearchResult]? {
        guard let entries = FileBrowser.entries(for: raw) else { return nil }
        return entries.map { entry in
            SearchResult(
                id: "browse:\(entry.path)",
                title: entry.name,
                subtitle: entry.path,
                icon: entry.isDirectory ? "symbol:folder" : "file:\(entry.path)",
                kind: entry.isDirectory ? "folder" : "file",
                payload: entry.path,
                category: "navigation",
                score: 2
            )
        }
    }

    func toggleLauncher() {
        if launcherVisible { hideLauncher(reactivate: true) } else { showLauncher() }
    }

    func showLauncher() {
        launcherEpoch += 1
        transientItem = nil
        typingCadence.beginSession()
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
        actionDrilled = false
        focusToken += 1
        SnippetExpander.shared.setSuspended(true)
        if previousApp != nil { sinkPreferencesBehindOtherApps() }
        scheduleSearch()
        launcher?.show()
    }

    func hideLauncher(reactivate: Bool) {
        launcherEpoch += 1
        cancelFileSearch()
        stopScriptFilter()
        transientItem = nil
        launcherVisible = false
        actionPanelVisible = false
        actionDrilled = false
        if !preferences.showLatestQuery {
            query = ""
            results = []
            selection = 0
            renderedQuery = ""
        }
        SnippetExpander.shared.setSuspended(false)
        launcher?.hide()
        if reactivate, let previousApp {
            previousApp.activate()
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

    func selectIndex(_ index: Int) {
        guard results.indices.contains(index) else { return }
        selection = index
    }

    func commitIndex(_ index: Int) {
        guard results.indices.contains(index) else { return }
        selection = index
        run(results[index], forced: "primary")
    }

    func handleResultClick(index: Int, clickCount: Int) {
        let viewer = ClipboardPreview.isViewerQuery(query, keyword: preferences.clipboardViewerKeyword)
        switch ClipboardPreview.resultClickIntent(clickCount: clickCount, clipboardViewer: viewer) {
        case .select:
            selectIndex(index)
        case .activate:
            commitIndex(index)
        }
    }

    func showActions() {
        guard results.indices.contains(selection) else { return }
        var actions = actions(for: results[selection])
        // Application file actions keep the fixed order, so ⌘1–⌘9 stay put.
        if preferences.uaSortByUsage, results[selection].kind != "app" {
            actions.sort { lhs, rhs in
                let left = Int(knowledge["ua.\(lhs.kind.rawValue)"] ?? "") ?? 0
                let right = Int(knowledge["ua.\(rhs.kind.rawValue)"] ?? "") ?? 0
                return left > right
            }
        }
        guard !actions.isEmpty else { return }
        actionDrilled = false
        actionRoot = actions
        launcherActions = actions
        actionPanelVisible = true
        actionIndex = 0
        launcher?.layout()
    }

    func closeActions() {
        guard actionPanelVisible else { return }
        actionPanelVisible = false
        actionDrilled = false
        actionIndex = 0
        launcher?.layout()
    }

    func backActions() {
        guard actionDrilled else {
            closeActions()
            return
        }
        actionDrilled = false
        launcherActions = actionRoot
        actionIndex = 0
        launcher?.layout()
    }

    func moveAction(_ delta: Int) {
        guard actionPanelVisible, !launcherActions.isEmpty else { return }
        actionIndex = (actionIndex + delta + launcherActions.count) % launcherActions.count
    }

    func commitAction(at index: Int? = nil) {
        let index = index ?? actionIndex
        guard actionPanelVisible, launcherActions.indices.contains(index), results.indices.contains(selection) else { return }
        let item = results[selection]
        let action = launcherActions[index]
        switch action.kind {
        case .recentDocuments:
            noteActionUse(FileActionID.recentDocuments.rawValue)
            showRecentDocuments(item.payload)
            return
        case .unavailable:
            return
        case .openPath:
            noteActionUse("openPath")
            let path = action.argument
            closeActions()
            openFile(path)
            return
        default:
            break
        }
        if item.kind == "app", let fileAction = action.fileActionID {
            closeActions()
            perform(fileAction: fileAction, on: item)
            return
        }
        noteActionUse(action.kind.rawValue)
        let value = item.payload.isEmpty ? item.title : item.payload
        closeActions()
        switch action.kind {
        case .open:
            run(item, forced: "primary")
        case .reveal:
            reveal(item)
            hideLauncher(reactivate: false)
        case .copyPath:
            copyPath(value)
        case .copyName:
            writeClipboard(item.title)
            hideLauncher(reactivate: false)
        case .copyValue:
            writeClipboard(item.kind == "snippet" ? expandedSnippet(item).text : value)
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
            if item.kind == "snippet" {
                let expansion = expandedSnippet(item)
                pasteToPrevious(expansion.text, cursorOffset: expansion.cursorOffset)
            } else {
                pasteToPrevious(value)
            }
        case .searchWeb:
            let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                NSWorkspace.shared.open(url)
            }
            hideLauncher(reactivate: false)
        case .recentDocuments, .showPackageContents, .openWith, .getInfo, .copyTo, .moveTo, .delete, .copyReplacing, .moveReplacing, .browseFolder, .openTerminal, .copyFile, .openPath, .unavailable:
            break
        }
    }

    func perform(fileAction: FileActionID, on item: SearchResult) {
        let path = item.payload
        guard path.hasPrefix("/") else { return }
        noteActionUse(fileAction.rawValue)
        switch fileAction {
        case .recentDocuments:
            showRecentDocuments(path)
        case .showPackageContents:
            showPackageContents(path)
        case .open:
            run(item, forced: "primary")
        case .openWith:
            openWith(path)
        case .reveal:
            reveal(item)
            hideLauncher(reactivate: false)
        case .getInfo:
            getInfo(path)
        case .copyTo:
            transfer(path, move: false, replace: false)
        case .moveTo:
            transfer(path, move: true, replace: false)
        case .delete:
            trash(path)
        case .copyReplacing:
            transfer(path, move: false, replace: true)
        case .moveReplacing:
            transfer(path, move: true, replace: true)
        case .browseFolder:
            browseEnclosing(path)
        case .openTerminal:
            openTerminal(at: path)
        case .copyPath:
            copyPath(path)
        case .copyFile:
            copyFile(path)
        }
    }

    func openFile(_ path: String) {
        guard path.hasPrefix("/") else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
        hideLauncher(reactivate: false)
    }

    private func actions(for item: SearchResult) -> [LauncherAction] {
        let appActions = FileActions.items(kind: item.kind, path: item.payload).map { action in
            launcherAction(for: action, result: item)
        }
        if !appActions.isEmpty { return appActions }
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

    private func launcherAction(for action: FileActionItem, result: SearchResult) -> LauncherAction {
        let subtitle: String
        switch action.id {
        case .reveal, .copyPath, .copyFile:
            subtitle = result.payload
        case .open:
            subtitle = result.title
        default:
            subtitle = action.subtitle
        }
        return LauncherAction(kind: action.id.actionKind, title: action.title, subtitle: subtitle, symbol: action.id.symbol)
    }

    private func noteActionUse(_ key: String) {
        knowledge["ua.\(key)"] = String((Int(knowledge["ua.\(key)"] ?? "") ?? 0) + 1)
        scheduleSave()
    }

    private func showRecentDocuments(_ path: String) {
        let documents = RecentDocuments.urls(forAppAt: path)
        if documents.isEmpty {
            launcherActions = [LauncherAction(kind: .unavailable, title: "No Recent Documents", subtitle: "Show recent documents for application", symbol: "doc")]
        } else {
            launcherActions = documents.map { document in
                LauncherAction(kind: .openPath, title: document.name, subtitle: document.path, symbol: "doc", argument: document.path)
            }
        }
        actionDrilled = true
        actionIndex = 0
        actionPanelVisible = true
        launcher?.layout()
    }

    private func showPackageContents(_ path: String) {
        let contents = URL(fileURLWithPath: path).appendingPathComponent("Contents", isDirectory: true)
        hideLauncher(reactivate: false)
        guard FileManager.default.fileExists(atPath: contents.path) else { return }
        NSWorkspace.shared.open(contents)
    }

    private func openWith(_ path: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = "Open"
        panel.message = "Choose an application."
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if let appType = UTType(filenameExtension: "app") {
            panel.allowedContentTypes = [appType]
        }
        resignLauncherForDialog()
        guard panel.runModal() == .OK, let app = panel.url else { return }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: app, configuration: config)
    }

    private func getInfo(_ path: String) {
        let quoted = appleString(path)
        hideLauncher(reactivate: false)
        let script = """
        tell application "Finder"
          activate
          open information window of (POSIX file \(quoted) as alias)
        end tell
        """
        CommandQueue.run { _ = Shell.osascript(script) }
    }

    private func transfer(_ path: String, move: Bool, replace: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = move ? "Move" : "Copy"
        panel.message = replace
            ? "Choose a folder. An existing item with the same name is replaced."
            : (move ? "Choose a folder to move into." : "Choose a folder to copy into.")
        resignLauncherForDialog()
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let source = URL(fileURLWithPath: path)
        let destination = folder.appendingPathComponent(source.lastPathComponent)
        if destination.standardizedFileURL.path == source.standardizedFileURL.path { return }
        let exists = FileManager.default.fileExists(atPath: destination.path)
        if exists, !replace {
            let alert = NSAlert()
            alert.messageText = "\(source.lastPathComponent) already exists"
            alert.informativeText = destination.path
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        let destinationName = source.lastPathComponent
        Task.detached {
            do {
                if exists { try FileManager.default.removeItem(at: destination) }
                if move {
                    try FileManager.default.moveItem(at: source, to: destination)
                } else {
                    try FileManager.default.copyItem(at: source, to: destination)
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "Couldn't \(move ? "move" : "copy") \(destinationName)"
                    alert.informativeText = message
                    alert.runModal()
                }
            }
        }
    }

    private func trash(_ path: String) {
        let url = URL(fileURLWithPath: path)
        let alert = NSAlert()
        alert.messageText = "Move “\(url.lastPathComponent)” to the Trash?"
        alert.informativeText = path
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        resignLauncherForDialog()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func browseEnclosing(_ path: String) {
        let parent = (path as NSString).deletingLastPathComponent
        guard parent.hasPrefix("/") else { return }
        closeActions()
        fromHistory = true
        query = parent.hasSuffix("/") ? parent : parent + "/"
    }

    private func openTerminal(at path: String) {
        let folder = (path as NSString).deletingLastPathComponent
        guard folder.hasPrefix("/") else { return }
        let quoted = "'" + folder.replacingOccurrences(of: "'", with: "'\\''") + "'"
        hideLauncher(reactivate: false)
        runInTerminal("cd \(quoted)")
    }

    private func copyPath(_ path: String) {
        let escaped: String
        if preferences.fileEscapePathForTerminal {
            escaped = "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        } else {
            escaped = path
        }
        writeClipboard(escaped)
        hideLauncher(reactivate: false)
    }

    private func copyFile(_ path: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.writeObjects([URL(fileURLWithPath: path) as NSURL])
        hideLauncher(reactivate: false)
    }

    private func resignLauncherForDialog() {
        NSApp.activate(ignoringOtherApps: true)
        hideLauncher(reactivate: false)
    }

    private func appleString(_ text: String) -> String {
        let clean = text.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
        let escaped = clean
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
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
        launcher?.showQuickLook(path: path)
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
            let text = query.isEmpty ? item.title : query
            hideLauncher(reactivate: false)
            searchFinder(text)
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
        case "folder":
            query = item.payload.hasSuffix("/") ? item.payload : item.payload + "/"
            scheduleSearch()
        case "file":
            let paths = fileBuffer.isEmpty ? [item.payload] : fileBuffer.map(\.payload)
            let policy = FileOpenPolicy(preferences: preferences)
            if policy.revealInsteadOfOpening {
                NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
            } else {
                for path in paths {
                    var isDirectory: ObjCBool = false
                    let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                    let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
                    let steps = policy.steps(
                        exists: exists,
                        isDirectory: isDirectory.boolValue,
                        isAppleScript: (path as NSString).pathExtension.lowercased() == "scpt",
                        resolvesElsewhere: resolved != path
                    )
                    for step in steps {
                        switch step {
                        case .reveal:
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                        case .runAppleScript:
                            UserScriptQueue.run { _ = Shell.run("/usr/bin/osascript", [path], timeout: 30) }
                        case .open:
                            NSWorkspace.shared.open(URL(fileURLWithPath: path))
                        case .touch:
                            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: path)
                        case .touchResolvedTarget:
                            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: resolved)
                        }
                    }
                }
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
            hideLauncher(reactivate: false)
            openPlace(item.payload)
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
        case "calculation", "copy":
            pasteToPrevious(item.payload.isEmpty ? item.title : item.payload)
        case "snippet":
            let expansion = expandedSnippet(item)
            pasteToPrevious(expansion.text, cursorOffset: expansion.cursorOffset)
        case "dictionary":
            let body = item.subtitle == "Open Dictionary" ? item.title : item.subtitle
            if let url = URL(string: "dict://\(item.payload.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? item.payload)") {
                NSWorkspace.shared.open(url)
            }
            hideLauncher(reactivate: false)
            if preferences.dictionaryPasteOnAction {
                pasteToPrevious(item.payload.isEmpty ? item.title : item.payload)
            } else {
                showLarge(body)
            }
        case "system":
            // Confirm while the launcher is still up, then hide it before the
            // command runs so it never sits frozen on screen.
            let effect = confirmedSystemEffect(item.payload)
            hideLauncher(reactivate: false)
            if let effect { performSystem(effect) }
        case "terminal":
            hideLauncher(reactivate: false)
            runInTerminal(item.payload)
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
        case "workflow":
            guard let payload = WorkflowRunPayload.decode(item.payload) else {
                debugLine = "The workflow result was malformed."
                return
            }
            hideLauncher(reactivate: false)
            let running = workflows
            Task {
                guard let state = await WorkflowRuntime.run(payload: payload, workflows: running, forced: forced) else {
                    await MainActor.run { self.debugLine = "The workflow could not be found." }
                    return
                }
                await MainActor.run {
                    for entry in state.logs {
                        let prefix = entry.isError ? "⚠︎" : "•"
                        let output = entry.output.isEmpty ? "" : "  ↳ " + entry.output.replacingOccurrences(of: "\n", with: " ")
                        self.debugLines.append("\(prefix) \(entry.title): \(entry.detail)\(output)")
                    }
                    self.debugLine = state.logs.last.map { "\($0.title): \($0.detail)" } ?? "Workflow finished"
                    self.applyWorkflowEffects(state.effects)
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
        if usage.count > StateStore.usageLimit { usage.removeFirst(usage.count - StateStore.usageLimit) }
        scheduleSave()
    }

    func preferencesChanged(from old: Preferences) {
        scheduleSave()
        if old.hotkey != preferences.hotkey || old.clipboardEnabled != preferences.clipboardEnabled { applyHotkeys() }
        if old.launchAtLogin != preferences.launchAtLogin { applyLoginItem() }
        if old.snippetsEnabled != preferences.snippetsEnabled { applyExpander() }
        let appRootsChanged = old.scopePaths != preferences.scopePaths || old.includeSystemApps != preferences.includeSystemApps || old.includeUserApps != preferences.includeUserApps || old.includePreferencePanes != preferences.includePreferencePanes || old.scopeApplications != preferences.scopeApplications
        if appRootsChanged {
            reindex()
            IndexWatch.shared.restartApps(preferences)
        }
        if old.onePasswordEnabled != preferences.onePasswordEnabled && preferences.onePasswordEnabled { reloadOnePassword() }
        if !preferences.fileBufferEnabled { fileBuffer = []; fileBufferLastUsed = nil }
        if old.safariBookmarks != preferences.safariBookmarks || old.chromeBookmarks != preferences.chromeBookmarks { reloadLinks() }
        if old.autoUpdateCheck != preferences.autoUpdateCheck {
            retargetUpdateChannel()
        }
    }

    func workflowsChanged() {
        scheduleSave()
        applyHotkeys()
        if selectedWorkflow == nil { selectedWorkflow = workflows.first?.id }
    }

    func workflowEdited() {
        scheduleSave()
    }

    func openWorkflowConfig(showsWorkflow: Bool) {
        guard let id = editingWorkflowID ?? selectedWorkflow,
              let workflow = workflows.first(where: { $0.id == id }) else { return }
        workflowConfigSnapshot = workflow
        workflowConfigShowsWorkflow = showsWorkflow
        workflowConfigEditsMetadata = false
        workflowConfigPresented = true
    }

    func openWorkflowMetadata() {
        guard let id = editingWorkflowID ?? selectedWorkflow,
              let workflow = workflows.first(where: { $0.id == id }) else { return }
        workflowConfigSnapshot = workflow
        workflowConfigShowsWorkflow = true
        workflowConfigEditsMetadata = true
        workflowConfigPresented = true
    }

    func cancelWorkflowConfig() {
        if let snapshot = workflowConfigSnapshot,
           let index = workflows.firstIndex(where: { $0.id == snapshot.id }) {
            workflows[index] = snapshot
        }
        workflowConfigSnapshot = nil
        workflowConfigEditsMetadata = false
        workflowConfigPresented = false
    }

    func saveWorkflowConfig() {
        workflowConfigSnapshot = nil
        workflowEdited()
        workflowConfigPresented = false
    }

    func togglePaletteSection(_ title: String) {
        if workflowPaletteExpanded.contains(title) {
            workflowPaletteExpanded.remove(title)
        } else {
            workflowPaletteExpanded.insert(title)
        }
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
        let queryChanged = renderedQuery != query
        renderedQuery = query
        results = rows
        if queryChanged || !rows.indices.contains(selection) {
            selection = 0
        }
        // Draw icons off the main thread: the visible rows first, then the
        // rest of the list so scrolling finds them ready.
        func icons(_ rows: ArraySlice<SearchResult>) -> [IconCache.Request] {
            rows.flatMap { [$0.icon, $0.badge] }.compactMap(IconCache.Request.init(icon:))
        }
        IconCache.shared.prefetchResults(
            visible: icons(rows.prefix(LauncherMetrics.visibleRows)),
            rest: icons(rows.dropFirst(LauncherMetrics.visibleRows))
        )
        launcher?.layout()
    }

    func reindex() {
        let prefs = preferences
        Task.detached {
            let apps = AppIndexer.applications(preferences: prefs)
            await MainActor.run {
                self.apps = apps
                IconCache.shared.prefetch(apps.map { IconCache.Request(path: $0.path, style: .file) }, priority: .low)
                self.warmSearchIndex()
            }
        }
    }

    func reloadLinks() {
        let prefs = preferences
        Task.detached {
            let links = BookmarkIndex.load(preferences: prefs)
            await MainActor.run {
                self.links = links
                self.warmSearchIndex()
            }
        }
    }

    func reloadOnePassword() {
        Task.detached {
            let items = OnePassword.items()
            await MainActor.run {
                self.opItems = items
                self.warmSearchIndex()
            }
        }
    }

    /// Builds match keys for changed records off the main thread, so the first
    /// keystroke after apps or bookmarks reload does not pay for them.
    private func warmSearchIndex() {
        let context = makeContext(files: [], definition: nil)
        let current = searchIndex
        Task {
            let warmed = await Task.detached(priority: .userInitiated) {
                var index = current
                index.refresh(for: context)
                return index
            }.value
            // Records may have changed again, or a keystroke may already have
            // refreshed the index. Keep the warmed copy only if it still matches.
            let latest = self.makeContext(files: [], definition: nil)
            if warmed.isCurrent(for: latest) { self.searchIndex = warmed }
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
        if launcherVisible {
            hideLauncher(reactivate: false)
        }
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
        // Changing the activation policy can drop Carbon hot keys while the
        // policy transition is still in flight; register again once it settles.
        DispatchQueue.main.async { [weak self] in
            self?.applyHotkeys()
        }
        leavingDock = false
    }

    func quit() {
        prepareForTermination()
        AppRuntime.explicitQuit = true
        NSApp.terminate(nil)
    }

    /// Write what would otherwise be lost when the process exits: the
    /// debounced save and, when enabled, the cleared clipboard history. Runs
    /// for Quit Jfred and again from `applicationWillTerminate`, which also
    /// covers log out, restart and shut down.
    func prepareForTermination() {
        if preferences.clipboardClearOnQuit, !clips.isEmpty {
            clips = []
        }
        saveWork?.cancel()
        saveWork = nil
        save()
        // Wait for the background write, including one already in progress.
        stateWriter.flush()
    }

    func checkForUpdates(userInitiated: Bool) {
        if updatePhase == .downloading || updatePhase == .installing { return }
        if !userInitiated, updatePhase != .idle { return }
        updateGeneration += 1
        let generation = updateGeneration
        setUpdatePhase(.checking)
        Task { @MainActor in
            await self.runUpdateCheck(generation: generation)
        }
    }

    func installAvailableUpdate() {
        guard let release = pendingUpdate else { return }
        switch updatePhase {
        case .available, .failed:
            break
        default:
            return
        }
        setUpdatePhase(.downloading)
        Task { @MainActor in
            await self.runInstall(release)
        }
    }

    private func runUpdateCheck(generation: Int) async {
        do {
            let data = try await AppUpdater.fetchReleaseFeed(version: AppRelease.version)
            let catalog = try AppUpdateFeed.parse(data, architecture: AppUpdateFeed.currentArchitecture)
            guard generation == updateGeneration else { return }
            updateCatalog = catalog
            updateCatalogReady = true
            apply(AppUpdateFeed.offer(
                in: catalog,
                channel: UpdateChannel(preference: preferences.autoUpdateCheck),
                current: AppRelease.version
            ))
        } catch {
            guard generation == updateGeneration else { return }
            UpdateLog.append("check failed")
            let message = error is UpdateFeedError
                ? "The update feed was not valid."
                : "Couldn't check for updates. Check the network and try again."
            setUpdatePhase(.failed(message))
        }
    }

    private func runInstall(_ release: UpdateRelease) async {
        UpdateLog.append("install \(release.version)")
        do {
            let dmg = try await AppUpdater.download(
                release.asset,
                version: release.version,
                architecture: AppUpdateFeed.currentArchitecture
            )
            do {
                guard updatePhase == .downloading else {
                    try? FileManager.default.removeItem(at: dmg.deletingLastPathComponent())
                    return
                }
                setUpdatePhase(.installing)
                let bundle = try UpdateInstaller.runningBundle()
                try await Task.detached {
                    try UpdateInstaller.apply(dmg: dmg, release: release, bundle: bundle)
                }.value
                quit()
            } catch {
                try? FileManager.default.removeItem(at: dmg.deletingLastPathComponent())
                throw error
            }
        } catch {
            UpdateLog.append("install failed")
            setUpdatePhase(.failed(UpdateInstallError.text(error)))
        }
    }

    private func retargetUpdateChannel() {
        guard updateCatalogReady else { return }
        switch updatePhase {
        case .downloading, .installing, .checking:
            return
        default:
            break
        }
        apply(AppUpdateFeed.offer(
            in: updateCatalog,
            channel: UpdateChannel(preference: preferences.autoUpdateCheck),
            current: AppRelease.version
        ))
    }

    private func apply(_ offer: UpdateOffer) {
        switch offer {
        case .upToDate(_, let notes):
            pendingUpdate = nil
            updateNotes = notes
            setUpdatePhase(.current)
        case .available(let release):
            pendingUpdate = release
            updateNotes = release.notes
            setUpdatePhase(.available)
        case .unavailable(let message):
            pendingUpdate = nil
            updateNotes = message
            setUpdatePhase(.current)
        }
    }

    private func setUpdatePhase(_ phase: UpdatePhase) {
        updatePhase = phase
        rebuildStatusMenu()
    }

    private func modifierAction(_ flags: NSEvent.ModifierFlags) -> String {
        if flags.contains(.command) { return preferences.modifierCommand }
        if flags.contains(.option) { return preferences.modifierOption }
        if flags.contains(.control) { return preferences.modifierControl }
        if flags.contains(.shift) { return "shift" }
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
        if let rootPath = workflow.rootPath {
            let url = URL(fileURLWithPath: rootPath, isDirectory: true)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                return url
            }
            if let relocated = JfredStore.relocatedRootPath(rootPath) {
                return URL(fileURLWithPath: relocated, isDirectory: true)
            }
            return nil
        }
        guard let bundle = workflow.builtin else { return nil }
        let entries = (try? FileManager.default.contentsOfDirectory(at: JfredStore.importedWorkflowsURL(), includingPropertiesForKeys: nil)) ?? []
        return entries.first { entry in
            guard let data = try? Data(contentsOf: entry.appendingPathComponent("info.plist")),
                  let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                  let info = propertyList as? [String: Any] else { return false }
            return info["bundleid"] as? String == bundle
        }
    }

    func importWorkflow(at url: URL) {
        section = .workflows
        showPreferences()
        switch JfredStore.importWorkflow(at: url) {
        case .failure(let error):
            let message = "Could not import \(url.lastPathComponent). \(error.errorDescription)"
            workflowImportStatus = message
            importNote = message
            presentWorkflowImportAlert(title: "Workflow import failed", message: message)
        case .success(let imported):
            JfredStore.syncWorkflows(self, JfredStore.workflows(), force: true)
            if let match = workflows.first(where: { $0.builtin == imported.bundleID || $0.bundleID == imported.bundleID || $0.rootPath == imported.destination.path }) {
                selectedWorkflow = match.id
            }
            let message = "Imported \(imported.name) from \(url.lastPathComponent)."
            workflowImportStatus = message
            importNote = message
        }
    }

    func revealImportedWorkflowsFolder() {
        let url = JfredStore.importedWorkflowsURL()
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func presentWorkflowImportAlert(title: String, message: String) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        if let window = preferencesWindow() {
            window.makeKeyAndOrderFront(nil)
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    func reloadWorkflowsFromAlfred() {
        JfredStore.syncWorkflows(self, JfredStore.reloadWorkflows(), force: true)
        let message = "Reloaded \(workflows.filter { $0.builtin != nil }.count) workflows."
        importNote = message
        workflowImportStatus = message
    }

    func importAlfredLibrary() {
        let count = JfredStore.importAllFromAlfred()
        JfredStore.syncWorkflows(self, JfredStore.reloadWorkflows(), force: true)
        importNote = "Imported \(count) workflows from Alfred."
        workflowImportStatus = importNote
        section = .workflows
        showPreferences()
    }

    func removeWorkflow(_ id: UUID) {
        guard let workflow = workflows.first(where: { $0.id == id }) else { return }
        JfredStore.deleteImportedCopy(workflow)
        workflows.removeAll { $0.id == id }
        if selectedWorkflow == id {
            selectedWorkflow = workflows.first?.id
            selectedWorkflowObject = nil
        }
        if editingWorkflowID == id {
            editingWorkflowID = nil
            workflowConfigPresented = false
            workflowConfigSnapshot = nil
        }
        workflowsChanged()
    }

    func duplicateWorkflow(_ id: UUID) {
        guard let index = workflows.firstIndex(where: { $0.id == id }) else { return }
        var copy = workflows[index]
        copy.id = UUID()
        copy.name += " Copy"
        copy.builtin = nil
        copy.bundleID = ""
        copy.rootPath = nil
        copy.hotkey = nil
        var remap: [UUID: UUID] = [:]
        for objectIndex in copy.objects.indices {
            let old = copy.objects[objectIndex].id
            let new = UUID()
            remap[old] = new
            copy.objects[objectIndex].id = new
            copy.objects[objectIndex].alfredUID = new.uuidString
        }
        copy.connections = copy.connections.map { connection in
            var connection = connection
            connection.id = UUID()
            connection.source = remap[connection.source] ?? connection.source
            connection.destination = remap[connection.destination] ?? connection.destination
            return connection
        }
        workflows.insert(copy, at: index + 1)
        selectedWorkflow = copy.id
        selectedWorkflowObject = nil
    }

    func addWorkflowObject(_ kind: WorkflowObjectKind) {
        guard let id = editingWorkflowID ?? selectedWorkflow,
              let index = workflows.firstIndex(where: { $0.id == id }) else { return }
        var config: [String: WorkflowValue] = [:]
        switch kind {
        case .keyword:
            config = ["keyword": .string("keyword"), "withspace": .boolean(true)]
        case .scriptFilter:
            config = ["keyword": .string("keyword"), "script": .string("echo '{\"items\": []}'"), "type": .integer(0), "scriptargtype": .integer(0)]
        case .runScript:
            config = ["script": .string("echo \"{query}\""), "type": .integer(0), "scriptargtype": .integer(0)]
        case .openURL:
            config = ["url": .string("https://www.google.com/search?q={query}")]
        case .clipboard:
            config = ["clipboardtext": .string("{query}")]
        case .largeType:
            config = ["text": .string("{query}")]
        case .notification:
            config = ["title": .string("Jfred"), "text": .string("{query}")]
        case .argument:
            config = ["argument": .string("{query}"), "passthroughargument": .boolean(false)]
        case .filter:
            config = ["inputstring": .string("{query}"), "matchstring": .string(".*"), "matchmode": .integer(4)]
        case .delay:
            config = ["seconds": .number(0.5)]
        default:
            break
        }
        let selected = workflows[index].objects.first { $0.id == selectedWorkflowObject }
        let position: WorkflowPoint
        if let selected {
            position = WorkflowPoint(x: selected.position.x + 240, y: selected.position.y)
        } else {
            position = WorkflowPoint(x: 40, y: 40)
        }
        let object = WorkflowObject(kind: kind, config: config, position: position)
        workflows[index].objects.append(object)
        if let selected, workflows[index].defaultOutgoing(from: selected.id) == nil {
            workflows[index].connect(selected.id, object.id)
        }
        selectedWorkflowObject = object.id
        workflowEdited()
    }

    func removeWorkflowObject(_ id: UUID) {
        guard let workflowID = editingWorkflowID ?? selectedWorkflow,
              let index = workflows.firstIndex(where: { $0.id == workflowID }) else { return }
        workflows[index].removeObject(id)
        if selectedWorkflowObject == id { selectedWorkflowObject = nil }
        workflowEdited()
    }

    func duplicateWorkflowObject(_ id: UUID) {
        guard let workflowID = editingWorkflowID ?? selectedWorkflow,
              let index = workflows.firstIndex(where: { $0.id == workflowID }),
              let object = workflows[index].objects.first(where: { $0.id == id }) else { return }
        var copy = object
        copy.id = UUID()
        copy.alfredUID = copy.id.uuidString
        copy.position = WorkflowPoint(x: object.position.x + 30, y: object.position.y + 30)
        workflows[index].objects.append(copy)
        if let outgoing = workflows[index].defaultOutgoing(from: id) {
            workflows[index].connect(copy.id, outgoing.destination)
        }
        selectedWorkflowObject = copy.id
        workflowEdited()
    }

    func moveWorkflowObject(_ id: UUID, to position: WorkflowPoint) {
        guard let workflowID = editingWorkflowID ?? selectedWorkflow,
              let index = workflows.firstIndex(where: { $0.id == workflowID }),
              let objectIndex = workflows[index].objects.firstIndex(where: { $0.id == id }) else { return }
        workflows[index].objects[objectIndex].position = position
        workflowEdited()
    }

    func connectWorkflowObject(_ source: UUID, to destination: UUID, modifiers: Int = 0) {
        guard let workflowID = editingWorkflowID ?? selectedWorkflow,
              let index = workflows.firstIndex(where: { $0.id == workflowID }) else { return }
        workflows[index].connect(source, destination, modifiers: modifiers)
        workflowEdited()
    }

    func disconnectWorkflowObject(_ source: UUID, destination: UUID) {
        guard let workflowID = editingWorkflowID ?? selectedWorkflow,
              let index = workflows.firstIndex(where: { $0.id == workflowID }) else { return }
        workflows[index].disconnect(source, destination)
        workflowEdited()
    }

    func runWorkflowDebug(_ id: UUID) {
        guard let workflow = workflows.first(where: { $0.id == id }),
              let input = workflow.searchInputs.first ?? workflow.objects.first else { return }
        let invocation = WorkflowInvocation(
            workflowID: workflow.id,
            inputID: input.id,
            keyword: input.keyword,
            argument: debugQuery,
            variables: workflow.variables
        )
        let resuming = debugPaused && debugWorkflowID == id && workflowDebugState != nil
        if !resuming {
            debuggerVisible = true
            debugLines = ["Running \(workflow.name) with query ‘\(debugQuery)’"]
            debugCursor = 0
            debugWorkflowID = id
            debugPaused = false
            debugLoggedCount = 0
            debugAppliedEffects = 0
            workflowDebugState = WorkflowRuntime.engine(for: workflow).initialState(invocation: invocation)
        }
        guard var state = workflowDebugState else { return }
        debugPaused = false
        let engine = WorkflowRuntime.engine(for: workflow)
        var skipBreakpoint = resuming
        Task {
            while !state.finished {
                if !skipBreakpoint, let next = state.pending.first,
                   let objectIndex = workflow.objects.firstIndex(where: { $0.id == next.objectID }),
                   self.debugBreakpoints.contains(objectIndex) {
                    await MainActor.run {
                        self.debugCursor = state.processed
                        self.debugPaused = true
                        self.workflowDebugState = state
                        self.debugLines.append("Paused before \(workflow.objects[objectIndex].title).")
                    }
                    return
                }
                skipBreakpoint = false
                await engine.step(&state)
                await MainActor.run {
                    self.appendWorkflowDebugLogs(state, workflow: workflow)
                    self.debugCursor = state.processed
                }
            }
            await MainActor.run {
                self.appendWorkflowDebugLogs(state, workflow: workflow)
                self.workflowDebugState = state
                self.debugPaused = false
                self.debugCursor = state.processed
                self.debugLines.append("Finished.")
            }
        }
    }

    func stepWorkflowDebug(_ id: UUID) {
        guard let workflow = workflows.first(where: { $0.id == id }),
              let input = workflow.searchInputs.first ?? workflow.objects.first else { return }
        if debugWorkflowID != id || workflowDebugState == nil {
            debugWorkflowID = id
            debugCursor = 0
            debugLoggedCount = 0
            debugAppliedEffects = 0
            debugLines = ["Stepping \(workflow.name) with query ‘\(debugQuery)’"]
            let invocation = WorkflowInvocation(
                workflowID: workflow.id,
                inputID: input.id,
                keyword: input.keyword,
                argument: debugQuery,
                variables: workflow.variables
            )
            workflowDebugState = WorkflowRuntime.engine(for: workflow).initialState(invocation: invocation)
        }
        debuggerVisible = true
        guard var state = workflowDebugState, !state.finished else {
            debugLines.append("Finished.")
            return
        }
        let engine = WorkflowRuntime.engine(for: workflow)
        Task {
            await engine.step(&state)
            await MainActor.run {
                self.appendWorkflowDebugLogs(state, workflow: workflow)
                self.workflowDebugState = state
                self.debugCursor = state.processed
                if state.finished { self.debugLines.append("Finished.") }
            }
        }
    }

    private func appendWorkflowDebugLogs(_ state: WorkflowRunState, workflow: Workflow) {
        guard state.logs.count > self.debugLoggedCount else { return }
        for entry in state.logs[self.debugLoggedCount...] {
            let output = entry.output.isEmpty ? "" : "  ↳ " + entry.output.replacingOccurrences(of: "\n", with: " ")
            self.debugLines.append("\(entry.isError ? "⚠︎" : "•") \(entry.title): \(entry.detail)\(output)")
        }
        self.debugLoggedCount = state.logs.count
        if state.effects.count > self.debugAppliedEffects {
            self.applyWorkflowEffects(Array(state.effects[self.debugAppliedEffects...]))
            self.debugAppliedEffects = state.effects.count
        }
        if let last = state.logs.last {
            self.debugLine = "\(last.title): \(last.detail)"
        }
        _ = workflow
    }

    private func applyWorkflowEffects(_ effects: [WorkflowEffect]) {
        for effect in effects {
            switch effect {
            case .openURL(let value):
                if let url = URL(string: value) {
                    NSWorkspace.shared.open(url)
                    noteURLHistory(value)
                }
            case .openFile(let value):
                let expanded = (value as NSString).expandingTildeInPath
                if FileManager.default.fileExists(atPath: expanded) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
                } else if !expanded.hasPrefix("/") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/\(expanded).app"))
                }
            case .revealFile(let value):
                let expanded = (value as NSString).expandingTildeInPath
                if FileManager.default.fileExists(atPath: expanded) {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: expanded)])
                }
            case .copy(let value):
                writeClipboard(value)
            case .largeType(let value):
                showLarge(value)
            case .notification(let title, let text):
                let script = "display notification \"\(appleScriptEscape(text))\" with title \"\(appleScriptEscape(title))\""
                Task.detached { _ = Shell.osascript(script) }
            case .playSound(let path):
                let expanded = (path as NSString).expandingTildeInPath
                if let sound = NSSound(contentsOfFile: expanded, byReference: true) { sound.play() } else { NSSound.beep() }
            case .speak(let text):
                Task.detached { _ = Shell.run("/usr/bin/say", [text]) }
            case .writeFile(let path, let text):
                let expanded = (path as NSString).expandingTildeInPath
                try? FileManager.default.createDirectory(at: URL(fileURLWithPath: expanded).deletingLastPathComponent(), withIntermediateDirectories: true)
                try? text.write(toFile: expanded, atomically: true, encoding: .utf8)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: expanded)
            case .terminal(let command):
                runInTerminal(command)
            case .unsupported(let detail):
                debugLine = detail
            }
        }
    }

    private func appleScriptEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func makeContext(files: [FileHit], definition: String?, forced: [SearchResult]? = nil) -> SearchContext {
        SearchContext(
            preferences: preferences,
            workflows: workflows,
            snippets: snippets,
            apps: apps,
            places: places(),
            settings: SettingsCatalog.all,
            links: links,
            clips: clips,
            files: files,
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
            CommandQueue.run {
                _ = Shell.osascript("""
                tell application "Finder"
                  activate
                  if (count of Finder windows) is 0 then make new Finder window
                  set target of front Finder window to computer container
                end tell
                """)
            }
        case "trash":
            CommandQueue.run { _ = Shell.osascript("tell application \"Finder\" to open trash") }
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
        let script = """
        tell application "Finder" to activate
        delay 0.15
        tell application "System Events" to tell process "Finder"
          keystroke "f" using command down
          delay 0.15
          keystroke "\(escaped)"
        end tell
        """
        CommandQueue.run { _ = Shell.osascript(script) }
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
        ClipboardBoard.write(clip, to: NSPasteboard.general)
        hideLauncher(reactivate: true)
        guard preferences.clipboardAutoPaste else { return }
        pasteIntoPreviousApp()
    }

    /// A snippet result's text with its placeholders filled in. The result's
    /// payload is the snippet id; `{clipboard}` reads the clipboard as it is now,
    /// before `pasteToPrevious` replaces it.
    private func expandedSnippet(_ item: SearchResult) -> SnippetExpansion {
        let template = snippets.first { $0.id.uuidString == item.payload }?.text ?? item.title
        return expandSnippet(template, clipboard: TemporaryClipboard.userText())
    }

    /// Paste `text` into the previous app. `cursorOffset` Left Arrows follow the
    /// paste to place a snippet's `{cursor}`.
    private func pasteToPrevious(_ text: String, cursorOffset: Int = 0) {
        let pending = TemporaryClipboard.write(text, restoring: preferences.selectionHotkeyMode == "restore")
        hideLauncher(reactivate: true)
        pasteIntoPreviousApp {
            SnippetExpander.shared.postIgnoringTap(KeyCode.leftArrow, count: cursorOffset)
            if let pending {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    TemporaryClipboard.restore(pending)
                }
            }
        }
    }

    /// Wait for the previous app to become active (or the configured delay), then
    /// synthesize ⌘V. Retries once if the frontmost app is still Jfred.
    private func pasteIntoPreviousApp(after: (() -> Void)? = nil) {
        let delayMs = max(0, preferences.pasteDelayMs)
        let target = previousApp
        func firePaste(tries: Int) {
            let front = NSWorkspace.shared.frontmostApplication
            let ready = target == nil
                || front?.processIdentifier == target?.processIdentifier
                || front?.bundleIdentifier != Bundle.main.bundleIdentifier
            if ready || tries >= 1 {
                postKey(9, flags: .maskCommand)
                after?()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                firePaste(tries: 1)
            }
        }
        if let target {
            target.activate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
            firePaste(tries: 0)
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

    /// The system command for `id`, once the user has confirmed it when
    /// Preferences asks for that. Nil when it is disabled or cancelled. The
    /// alert runs here, on the main thread, before any command work starts.
    private func confirmedSystemEffect(_ id: String) -> SystemEffect? {
        guard let effect = ActionExecutor.systemEffect(id: id, disabled: preferences.systemDisabled, ejectScope: preferences.ejectScope) else { return nil }
        if case .setOutputVolume = effect { return effect }
        if preferences.systemConfirm.contains(id) {
            let alert = NSAlert()
            alert.messageText = "Run this system command?"
            alert.informativeText = "This action may interrupt what you are doing."
            alert.addButton(withTitle: "Continue")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        }
        return effect
    }

    private func performSystem(_ effect: SystemEffect) {
        if effect.runsOnCommandQueue {
            let exclusions = preferences.ejectExclusions
            CommandQueue.run { SystemEffectRunner.perform(effect, ejectExclusions: exclusions) }
            return
        }
        switch effect {
        case .quitAll:
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                app.terminate()
            }
        case .showDesktop: postKey(103)
        case .missionControl: NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
        case .launchpad:
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.launchpad.launcher") {
                NSWorkspace.shared.open(url)
            }
        case .screenshot:
            Task.detached { _ = Shell.run("/usr/sbin/screencapture", ["-i"], timeout: 60) }
        case .unknown(let name):
            debugLine = "Unknown command \(name)"
        default:
            break
        }
    }

    /// Open `command` in the preferred terminal. The AppleScript or `open`
    /// call runs on `CommandQueue`, never on the main thread.
    private func runInTerminal(_ command: String) {
        let escaped = command
            .replacingOccurrences(of: "\0", with: "")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let terminalScript = """
        tell application "Terminal"
          activate
          do script "\(escaped)"
        end tell
        """
        switch preferences.terminalApp {
        case "iTerm":
            let script = """
            tell application "iTerm"
              activate
              create window with default profile
              tell current session of current window to write text "\(escaped)"
            end tell
            """
            CommandQueue.run { _ = Shell.osascript(script) }
        case "Ghostty":
            CommandQueue.run { _ = Shell.run("/usr/bin/open", ["-na", "Ghostty", "--args", "-e", "/bin/zsh", "-lc", command]) }
        case "Alacritty":
            CommandQueue.run { _ = Shell.run("/usr/bin/open", ["-na", "Alacritty", "--args", "-e", "/bin/zsh", "-lc", command]) }
        case "Custom":
            let custom = preferences.terminalCustomScript.replacingOccurrences(of: "{query}", with: escaped)
            let script = custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? terminalScript : custom
            CommandQueue.run { _ = Shell.osascript(script) }
        default:
            CommandQueue.run { _ = Shell.osascript(terminalScript) }
        }
    }

    func applyHotkeys() {
        let ok = HotkeyCenter.shared.register(id: 1, keyCode: UInt32(preferences.hotkey.keyCode), modifiers: preferences.hotkey.carbonModifiers) { [weak self] in
            Self.runOnMain { self?.toggleLauncher() }
        }
        let selectionHotkeyOK = HotkeyCenter.shared.register(id: 2, keyCode: 42, modifiers: Hotkey(keyCode: 42, modifiers: Hotkey.option | Hotkey.command).carbonModifiers) { [weak self] in
            Self.runOnMain { self?.showSelectionActions() }
        }
        selectionHotkeyWarning = selectionHotkeyOK ? "" : "⌥⌘\\ is already used by another app."
        if preferences.clipboardEnabled {
            let clipboardHotkey = Hotkey(keyCode: 8, modifiers: Hotkey.option | Hotkey.command)
            let clipboardHotkeyOK = HotkeyCenter.shared.register(id: 3, keyCode: UInt32(clipboardHotkey.keyCode), modifiers: clipboardHotkey.carbonModifiers) { [weak self] in
                Self.runOnMain { self?.showClipboardViewer() }
            }
            clipboardHotkeyWarning = clipboardHotkeyOK ? "" : "⌥⌘C is already used by another app."
        } else {
            HotkeyCenter.shared.unregister(id: 3)
            clipboardHotkeyWarning = ""
        }
        for id in workflowHotkeyIDs { HotkeyCenter.shared.unregister(id: id) }
        workflowHotkeyIDs.removeAll()
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
            let registered = HotkeyCenter.shared.register(id: id, keyCode: UInt32(hotkey.keyCode), modifiers: hotkey.carbonModifiers, handler: { [weak self] in
                Self.runOnMain {
                    self?.query = keyword + " "
                    self?.showLauncher()
                }
            })
            if registered {
                workflowHotkeyIDs.append(id)
            }
        }
    }

    /// HotkeyCenter already hops to the main thread once. Call handlers directly
    /// when we are on main; otherwise one async hop is enough.
    private static func runOnMain(_ body: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { body() }
        } else {
            DispatchQueue.main.async { body() }
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

    func showClipboardViewer() {
        guard preferences.clipboardEnabled else { return }
        let keyword = preferences.clipboardViewerKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = (keyword.isEmpty ? "clipboard" : keyword) + " "
        if launcherVisible, query == text {
            hideLauncher(reactivate: true)
            return
        }
        showLauncher()
        fromHistory = false
        query = text
        scheduleSearch()
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
        guard Self.finderIsFrontmost() else { return }
        // Asking Finder for its selection is an AppleScript round trip that can
        // take seconds. Fetch it off the main thread and present it when it
        // arrives, unless the launcher was used in the meantime.
        let epoch = launcherEpoch
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let files = Accessibility.finderSelection()
            Task { @MainActor in
                guard let self, self.launcherEpoch == epoch, Self.finderIsFrontmost() else { return }
                self.presentFinderSelection(files)
            }
        }
    }

    private static func finderIsFrontmost() -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
    }

    private func presentFinderSelection(_ files: [String]) {
        guard let first = files.first else { return }
        let title = (first as NSString).lastPathComponent
        presentTransient(SearchResult(
            id: "selection:file:\(first)", title: title, subtitle: files.count > 1 ? "\(files.count) selected files" : first,
            icon: "file:\(first)", kind: "file", payload: first, category: "action", score: 2
        ))
    }

    private func presentTransient(_ item: SearchResult) {
        launcherEpoch += 1
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

    private func pollClipboard() {
        let board = NSPasteboard.general
        guard preferences.clipboardEnabled, board.changeCount != clipChange else { return }
        clipChange = board.changeCount
        pruneClipboard()
        if ClipboardBoard.isOwnWrite(board) { return }
        if ClipboardBoard.shouldIgnore(app: NSWorkspace.shared.frontmostApplication, extra: preferences.clipboardIgnoreApps) { return }
        let types = Set(board.types ?? [])
        if types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")) { return }
        if preferences.clipboardIgnoreConcealed,
           types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) { return }
        if preferences.clipboardIgnoreAutoGenerated,
           types.contains(NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")) { return }
        let remote = types.contains(NSPasteboard.PasteboardType("com.apple.is-remote-clipboard"))
        let captured = ClipboardBoard.capture(board)
        let sourceApp = NSWorkspace.shared.frontmostApplication
        let sourcePath = sourceApp?.bundleURL?.path
        let sourceName = sourceApp?.localizedName
        if preferences.clipboardKeepFiles,
           !(remote && preferences.clipboardIgnoreUniversalFiles),
           !captured.fileURLs.isEmpty {
            let paths = captured.fileURLs.map(\.path)
            if preferences.clipboardIgnoreDuplicates, clips.first?.filePaths == paths { return }
            rememberClip(ClipItem(text: captured.fileURLs.map(\.lastPathComponent).joined(separator: ", "), date: Date(), kind: "file", filePaths: paths, sourcePath: sourcePath, sourceName: sourceName))
            return
        }
        if preferences.clipboardKeepImages,
           !(remote && preferences.clipboardIgnoreUniversalText),
           let data = captured.image, let type = captured.imageType {
            if preferences.clipboardIgnoreDuplicates, ClipboardBoard.sameImage(data, as: clips.first) { return }
            let directory = supportDirectory().appendingPathComponent("ClipImages", isDirectory: true)
            guard let path = ClipboardBoard.saveImage(data, type: type, directory: directory) else { return }
            let clip = ClipItem(text: "Image", date: Date(), kind: "image", imageFile: path, imageType: type, sourcePath: sourcePath, sourceName: sourceName)
            rememberClip(clip)
            let clipID = clip.id
            Task.detached(priority: .utility) { [weak self] in
                guard let recognized = ClipboardBoard.recognizeText(in: data) else { return }
                await MainActor.run { [weak self] in
                    guard let self, let index = self.clips.firstIndex(where: { $0.id == clipID }) else { return }
                    self.clips[index].text = recognized
                    self.scheduleSave()
                }
            }
            return
        }
        guard preferences.clipboardKeepText,
              !(remote && preferences.clipboardIgnoreUniversalText) else { return }
        guard let text = captured.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard text.count <= max(4_096, preferences.clipboardMaxSize) else { return }
        if preferences.clipboardIgnoreDuplicates,
           clips.first?.text == text,
           clips.first?.html == captured.html,
           clips.first?.rtf == captured.rtf { return }
        rememberClip(ClipItem(text: text, date: Date(), html: captured.html, rtf: captured.rtf, sourcePath: sourcePath, sourceName: sourceName))
    }

    private func rememberClip(_ clip: ClipItem) {
        clips.insert(clip, at: 0)
        if clips.count > preferences.clipboardLimit { clips = Array(clips.prefix(preferences.clipboardLimit)) }
        scheduleSave()
    }

    private func pruneClipboard() {
        guard !clips.isEmpty else { return }
        let now = Date()
        clips.removeAll { clip in
            let label = ClipboardRetention.label(forKind: clip.kind ?? "text", preferences: preferences)
            guard let interval = ClipboardRetention.interval(for: label) else { return false }
            return clip.date < now.addingTimeInterval(-interval)
        }
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

    private func applyDiskState(_ state: DiskState) {
        preferences = state.preferences
        workflows = state.workflows.filter { !WorkflowSync.isLegacyPlaceholder($0) }
        snippets = state.snippets
        clips = state.clips
        usage = state.usage
        knowledge = state.knowledge
        selections = state.selections
    }

    private func load() {
        hardenSupportFolder()
        JfredStore.migrateImportedWorkflowsIfNeeded()
        let directory = supportDirectory()
        let loaded = StateStore.load(directory: directory)
        if let state = loaded.state {
            if loaded.usedBackup {
                let line = "Jfred: state.json was unreadable; loaded workflows from state.json.bak\n"
                FileHandle.standardError.write(Data(line.utf8))
            }
            applyDiskState(state)
            let allSkipped = state.skippedWorkflowCount > 0 && state.workflows.isEmpty
            stateWriter.configure(canOverwriteStateFile: !allSkipped, canReplaceStateBackup: !allSkipped, protectedSections: loaded.protectedSections)
        } else {
            preferences = Preferences()
            workflows = Seed.workflows()
            snippets = Seed.snippets()
            clips = loaded.clips
            usage = loaded.usage
            // Do not overwrite an existing unreadable state.json or a good backup
            // with a seed state. First launch (no file yet) may still write.
            let url = directory.appendingPathComponent(StateFileName.state)
            stateWriter.configure(canOverwriteStateFile: !FileManager.default.fileExists(atPath: url.path), canReplaceStateBackup: false, protectedSections: loaded.protectedSections)
        }
        lastSaveDirectory = directory
        // Loading is not a change. Clips or usage still inside state.json move
        // to their own files with the first save.
        unsavedSections = loaded.sectionsToWrite
        finishJfredStore()
        if !loaded.sectionsToWrite.isEmpty { scheduleSave() }
    }

    private func finishJfredStore() {
        if knowledge["launcher.sync"] != "1", let loaded = JfredStore.apply(self) {
            knowledge["launcher.sync"] = "1"
            JfredStore.syncWorkflows(self, loaded)
            scheduleSave()
        } else {
            JfredStore.syncWorkflows(self, JfredStore.reloadWorkflows())
        }
    }

    func importLauncherSettings() {
        guard let loaded = JfredStore.apply(self) else { return }
        knowledge["launcher.sync"] = "1"
        JfredStore.syncWorkflows(self, loaded)
        applyHotkeys()
        applyExpander()
        refreshStatusItem()
        scheduleSave()
    }

    /// Delay before saving changes. Usage events only feed the statistics
    /// pane, so they wait longer and ride along with any other save.
    private static let saveDelay: TimeInterval = 0.35
    private static let usageSaveDelay: TimeInterval = 5

    private func scheduleSave() {
        let usageOnly = unsavedSections.isSubset(of: .usage)
        // A save is already coming; usage events join it without delaying it.
        if usageOnly, saveWork != nil { return }
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (usageOnly ? Self.usageSaveDelay : Self.saveDelay), execute: work)
    }

    private func hardenSupportFolder() {
        let dir = supportDirectory()
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        for name in [StateFileName.state, StateFileName.backup, StateFileName.clips, StateFileName.usage] {
            let file = dir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: file.path) {
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            }
        }
        let images = dir.appendingPathComponent("ClipImages", isDirectory: true)
        if let files = try? FileManager.default.contentsOfDirectory(at: images, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            }
        }
    }

    /// Hands the changed sections to `stateWriter`, which encodes and writes
    /// them on its own queue. Only copying the values happens here.
    private func save() {
        saveWork = nil
        var sections = unsavedSections
        let directory = supportDirectory()
        if directory != lastSaveDirectory {
            sections = .all
            lastSaveDirectory = directory
        }
        guard !sections.isEmpty else { return }
        unsavedSections = []
        var snapshot = StateWriter.Snapshot()
        if sections.contains(.main) {
            snapshot.main = DiskState(preferences: preferences, workflows: workflows, snippets: snippets, clips: [], usage: [], knowledge: knowledge, selections: selections)
        }
        if sections.contains(.clips) { snapshot.clips = clips }
        if sections.contains(.usage) { snapshot.usage = usage }
        stateWriter.submit(snapshot, to: directory)
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
        statusItem = item
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Jfred", action: #selector(statusShow), keyEquivalent: "")
        menu.addItem(withTitle: "Preferences", action: #selector(statusPrefs), keyEquivalent: ",")
        if let version = pendingUpdate?.version {
            menu.addItem(.separator())
            menu.addItem(withTitle: "Update to \(version)…", action: #selector(statusUpdate), keyEquivalent: "")
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Jfred", action: #selector(statusQuit), keyEquivalent: "q")
        for entry in menu.items { entry.target = self }
        statusItem.menu = menu
    }

    private var statusItem: NSStatusItem?

    @objc private func statusShow() { showLauncher() }
    @objc private func statusPrefs() { showPreferences() }
    @objc private func statusUpdate() {
        section = .update
        showPreferences()
    }
    @objc private func statusQuit() { quit() }
}

enum PrefSection: String, CaseIterable, Identifiable {
    case general, features, workflows, appearance, advanced, usage, help, update
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "General"
        case .features: "Features"
        case .workflows: "Workflows"
        case .appearance: "Appearance"
        case .advanced: "Advanced"
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
        case .advanced: "slider.horizontal.3"
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
            PreferenceHit(id: "theme", title: "Appearance themes", detail: "Built-in themes, custom themes and live preview", section: .appearance, feature: nil),
            PreferenceHit(id: "theme-files", title: "Import or export themes", detail: "Appearance .alfredappearance files", section: .appearance, feature: nil),
            PreferenceHit(id: "clipboard-ignore", title: "Clipboard Ignore Apps", detail: "Privacy and excluded applications", section: .features, feature: .clipboard),
            PreferenceHit(id: "snippet-expansion", title: "Auto Expansion Options", detail: "Snippets, sound and clipboard restore", section: .features, feature: .snippets),
            PreferenceHit(id: "workflow-debugger", title: "Workflow Debugger", detail: "Test query, Run, Step and breakpoints", section: .workflows, feature: nil),
            PreferenceHit(id: "universal-actions", title: "Universal Actions", detail: "Selection hotkey and action ordering", section: .features, feature: .universalActions),
            PreferenceHit(id: "help", title: "Help and diagnostics", detail: "Troubleshooting, permissions, Copy Diagnostics", section: .help, feature: nil),
            PreferenceHit(id: "update", title: "Check for Updates", detail: "Download a GitHub release and relaunch in place", section: .update, feature: nil),
        ]
        for feature in FeatureID.allCases {
            rows.append(PreferenceHit(id: feature.id, title: feature.title, detail: feature.subtitle, section: .features, feature: feature))
        }
        return rows
    }()
}

extension AppModel {
    func workflowDestination(source: UUID, modifiers: Int) -> UUID? {
        guard let workflowID = editingWorkflowID ?? selectedWorkflow,
              let workflow = workflows.first(where: { $0.id == workflowID }) else { return nil }
        return workflow.connections.first { $0.source == source && $0.modifiers == modifiers && ($0.sourceOutputUID ?? "").isEmpty }?.destination
    }

    func setWorkflowDestination(source: UUID, modifiers: Int, destination: UUID?) {
        guard let workflowID = editingWorkflowID ?? selectedWorkflow,
              let index = workflows.firstIndex(where: { $0.id == workflowID }) else { return }
        workflows[index].connections.removeAll { $0.source == source && $0.modifiers == modifiers && ($0.sourceOutputUID ?? "").isEmpty }
        if let destination, destination != source {
            workflows[index].connections.append(WorkflowConnection(source: source, destination: destination, modifiers: modifiers))
        }
    }

    func workflowBranchDestination(source: UUID, sourceOutputUID: String) -> UUID? {
        guard let workflowID = editingWorkflowID ?? selectedWorkflow,
              let workflow = workflows.first(where: { $0.id == workflowID }) else { return nil }
        return workflow.connections.first { $0.source == source && $0.sourceOutputUID == sourceOutputUID }?.destination
    }

    func setWorkflowBranchDestination(source: UUID, sourceOutputUID: String, destination: UUID?) {
        guard let workflowID = editingWorkflowID ?? selectedWorkflow,
              let index = workflows.firstIndex(where: { $0.id == workflowID }) else { return }
        workflows[index].connections.removeAll { $0.source == source && $0.sourceOutputUID == sourceOutputUID }
        if let destination, destination != source {
            workflows[index].connections.append(WorkflowConnection(source: source, destination: destination, sourceOutputUID: sourceOutputUID))
        }
    }

    func workflowConditionLabel(_ workflowID: UUID, _ objectID: UUID, _ index: Int) -> String {
        guard let object = workflows.first(where: { $0.id == workflowID })?.object(id: objectID),
              let conditions = object.config["conditions"]?.arrayValue,
              conditions.indices.contains(index),
              let bits = conditions[index].objectValue else { return "Condition \\(index + 1)" }
        let label = bits[string: "outputlabel"]
        return label.isEmpty ? "Condition \\(index + 1)" : label
    }
}

extension AppModel {
    func setBreakpoint(_ index: Int, _ enabled: Bool) {
        if enabled { debugBreakpoints.insert(index) } else { debugBreakpoints.remove(index) }
    }
}

extension AppModel {
    func setWorkflowHotkey(_ id: UUID, keyCode: UInt16, modifiers: UInt) {
        guard let index = workflows.firstIndex(where: { $0.id == id }) else { return }
        workflows[index].hotkey = Hotkey(keyCode: keyCode, modifiers: modifiers)
        workflowsChanged()
    }

    func clearWorkflowHotkey(_ id: UUID) {
        guard let index = workflows.firstIndex(where: { $0.id == id }) else { return }
        workflows[index].hotkey = nil
        workflowsChanged()
    }

    func setWorkflowDelay(_ objectID: UUID, _ seconds: Double) {
        guard let workflowID = editingWorkflowID ?? selectedWorkflow,
              let workflowIndex = workflows.firstIndex(where: { $0.id == workflowID }),
              let objectIndex = workflows[workflowIndex].objects.firstIndex(where: { $0.id == objectID }) else { return }
        workflows[workflowIndex].objects[objectIndex].config["seconds"] = .number(max(0, min(30, seconds)))
    }
}
