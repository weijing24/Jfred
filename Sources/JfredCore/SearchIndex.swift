import Foundation

/// Match keys for the launcher's searchable records, built when the records
/// change instead of on every keystroke.
///
/// Each section keeps the records it was built from and `refresh(for:)` compares
/// them with the context. Arrays that share storage compare in constant time, so
/// an unchanged section costs nothing, and a changed section is rebuilt from the
/// new records. A stale or missing index therefore never changes results; it only
/// costs a rebuild.
public struct SearchIndex: Sendable {
    struct Section<Record: Equatable & Sendable, Entry: Sendable>: Sendable {
        private(set) var records: [Record] = []
        private(set) var entries: [Entry] = []

        mutating func refresh(_ current: [Record], prepare: (Record) -> Entry) {
            if current == records {
                // Same content in another array: keep it so later checks hit
                // the shared-storage fast path.
                records = current
                return
            }
            records = current
            entries = current.map(prepare)
        }

        func isCurrent(_ current: [Record]) -> Bool {
            current == records
        }
    }

    struct AppEntry: Sendable {
        /// `Search.includeApp(path:)` for the app's path.
        let included: Bool
        let keys: [MatchKey]
    }

    struct SnippetEntry: Sendable {
        let name: MatchKey
        let keyword: MatchKey
    }

    struct WorkflowEntry: Sendable {
        /// `Workflow.keyword` walks the object graph; read it once.
        let keyword: String
        let keys: [MatchKey]
    }

    struct CommandEntry: Sendable {
        let title: MatchKey
        let titleAndKeywords: [MatchKey]
    }

    private(set) var apps = Section<AppRecord, AppEntry>()
    private(set) var places = Section<AppRecord, MatchKey>()
    private(set) var settings = Section<SettingRecord, MatchKey>()
    private(set) var snippets = Section<Snippet, SnippetEntry>()
    private(set) var workflows = Section<Workflow, WorkflowEntry>()
    private(set) var links = Section<LinkRecord, [MatchKey]>()
    private(set) var opItems = Section<AppRecord, MatchKey>()
    private(set) var systemKeywordSource: [String: String] = [:]
    /// Custom system command keywords from preferences, by command id.
    private(set) var systemKeywords: [String: MatchKey] = [:]

    /// `SystemCommand.all` never changes.
    static let commands: [CommandEntry] = SystemCommand.all.map { command in
        let title = MatchKey(command.title)
        return CommandEntry(title: title, titleAndKeywords: [title] + command.keywords.map(MatchKey.init))
    }

    public init() {}

    /// Rebuilds the sections whose records differ from the context's.
    public mutating func refresh(for context: SearchContext) {
        apps.refresh(context.apps) { app in
            AppEntry(
                included: Search.includeApp(path: app.path),
                keys: matchFields(forName: app.name, aliases: app.aliases).map(MatchKey.init)
            )
        }
        places.refresh(context.places) { MatchKey($0.name) }
        settings.refresh(context.settings) { MatchKey($0.name) }
        snippets.refresh(context.snippets) { SnippetEntry(name: MatchKey($0.name), keyword: MatchKey($0.keyword)) }
        workflows.refresh(context.workflows) { workflow in
            let keyword = workflow.keyword
            return WorkflowEntry(keyword: keyword, keys: [MatchKey(workflow.name), MatchKey(keyword)])
        }
        links.refresh(context.links) { [MatchKey($0.title), MatchKey($0.url)] }
        opItems.refresh(context.opItems) { MatchKey($0.name) }
        let custom = context.preferences.systemKeywords
        if custom != systemKeywordSource {
            systemKeywordSource = custom
            systemKeywords = custom.mapValues(MatchKey.init)
        }
    }

    /// True when every section was built from the context's records.
    public func isCurrent(for context: SearchContext) -> Bool {
        apps.isCurrent(context.apps)
            && places.isCurrent(context.places)
            && settings.isCurrent(context.settings)
            && snippets.isCurrent(context.snippets)
            && workflows.isCurrent(context.workflows)
            && links.isCurrent(context.links)
            && opItems.isCurrent(context.opItems)
            && systemKeywordSource == context.preferences.systemKeywords
    }
}
