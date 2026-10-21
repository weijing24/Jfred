import Foundation

public enum Search {
    /// Matches kept for the launcher. The window shows a shorter viewport and scrolls.
    public static let resultLimit = 40

    public static func results(for raw: String, context: SearchContext) -> [SearchResult] {
        if raw.hasPrefix(" ") {
            return cap(fileResults(query: raw.trimmingCharacters(in: .whitespacesAndNewlines), context: context))
        }
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        if let forced = context.forcedResults {
            return Array(forced.prefix(12))
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(">") {
            let command = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            return [make(
                id: "term:\(command)",
                title: command.isEmpty ? "Run in Terminal" : command,
                subtitle: "Run in \(context.preferences.terminalApp)",
                icon: "symbol:terminal",
                kind: "terminal",
                payload: command,
                category: "action",
                score: 2
            )]
        }
        if let openQuery = argument(of: "open", in: trimmed) ?? argument(of: "find", in: trimmed) {
            return cap(fileResults(query: openQuery, context: context))
        }
        if let volume = volumeValue(trimmed) {
            return [make(
                id: "sys:volume:\(volume)",
                title: "Set Volume to \(volume)",
                subtitle: "Output volume",
                icon: "symbol:speaker.wave.2",
                kind: "system",
                payload: "volume:\(volume)",
                category: "action",
                score: 2
            )]
        }

        if let exclusive = workflowResults(trimmed, context: context) {
            return cap(exclusive)
        }
        let webHits = mergedWebKeywords(for: trimmed, context: context)
        if !webHits.isEmpty {
            return cap(webHits)
        }

        var found: [SearchResult] = []
        if context.preferences.calculatorEnabled, let value = Calculator.evaluate(trimmed) {
            let text = Calculator.format(value)
            found.append(make(
                id: "calc:\(text)",
                title: text,
                subtitle: "Calculator  ·  \(trimmed)",
                icon: "symbol:plus.forwardslash.minus",
                kind: "calculation",
                payload: text,
                category: "general",
                score: 1.8
            ))
        }
        if let conversion = Units.convert(trimmed) {
            found.append(make(
                id: "unit:\(conversion.text)",
                title: conversion.text,
                subtitle: "Unit Converter  ·  \(trimmed)",
                icon: "symbol:ruler",
                kind: "calculation",
                payload: conversion.text,
                category: "general",
                score: 1.75
            ))
        }
        if context.preferences.dictionaryEnabled, let word = argument(of: "define", in: trimmed) {
            let subtitle = context.definition?.replacingOccurrences(of: "\n", with: " ") ?? "Open Dictionary"
            found.append(make(
                id: "dict:\(word)",
                title: word.isEmpty ? "Dictionary" : word,
                subtitle: String(subtitle.prefix(180)),
                icon: "symbol:character.book.closed",
                kind: "dictionary",
                payload: word,
                category: "general",
                score: 1.7
            ))
        }

        let needle = trimmed
        func push(_ item: SearchResult?) {
            if let item { found.append(item) }
        }

        for app in context.apps {
            push(scored(
                query: needle,
                fields: [app.name],
                id: "app:\(app.path)",
                title: app.name,
                subtitle: app.path,
                icon: "file:\(app.path)",
                kind: "app",
                payload: app.path,
                category: "general",
                context: context
            ))
        }
        for place in context.places {
            push(scored(
                query: needle,
                fields: [place.name],
                id: "place:\(place.id)",
                title: place.name,
                subtitle: place.id == "computer" ? "Open Computer in Finder" : place.path,
                icon: place.path.isEmpty ? "symbol:desktopcomputer" : "file:\(place.path)",
                kind: "place",
                payload: place.id,
                category: "navigation",
                context: context
            ))
        }
        if context.preferences.systemSettingsEnabled {
            let foldedQuery = fold(needle)
            for setting in context.settings where !foldedQuery.isEmpty && fold(setting.name).contains(foldedQuery) {
                push(scored(
                    query: needle,
                    fields: [setting.name],
                    id: "set:\(setting.id)",
                    title: setting.name,
                    subtitle: "System Settings",
                    icon: "symbol:gearshape",
                    kind: "settings",
                    payload: setting.url,
                    category: "general",
                    context: context
                ))
            }
        }
        for snippet in context.snippets where context.preferences.snippetsEnabled {
            push(scored(
                query: needle,
                fields: [snippet.name, snippet.keyword],
                id: "snip:\(snippet.id.uuidString)",
                title: snippet.name,
                subtitle: snippet.keyword + "  ·  " + snippet.text.replacingOccurrences(of: "\n", with: " "),
                icon: "symbol:text.quote",
                kind: "snippet",
                payload: snippet.id.uuidString,
                category: "expansion",
                context: context,
                floor: fold(needle) == fold(snippet.keyword) ? 1.55 : nil
            ))
        }
        for command in SystemCommand.all {
            if command.category == "music" { continue }
            push(scored(
                query: needle,
                fields: [command.title] + command.keywords,
                id: "sys:\(command.id)",
                title: command.title,
                subtitle: command.subtitle,
                icon: "symbol:\(command.symbol)",
                kind: "system",
                payload: command.id,
                category: command.category,
                context: context
            ))
        }
        for workflow in context.workflows where workflow.enabled && workflow.builtin == nil {
            push(scored(
                query: needle,
                fields: [workflow.name, workflow.keyword],
                id: "complete:\(workflow.id.uuidString)",
                title: workflow.name,
                subtitle: workflow.keyword,
                icon: "symbol:\(workflow.symbol)",
                kind: "complete",
                payload: workflow.keyword + " ",
                category: "action",
                context: context
            ))
        }
        for workflow in context.workflows where workflow.enabled && workflow.builtin != nil {
            push(scored(
                query: needle,
                fields: [workflow.name, workflow.keyword],
                id: "complete:\(workflow.id.uuidString)",
                title: workflow.name,
                subtitle: workflow.keyword,
                icon: "symbol:\(workflow.symbol)",
                kind: "complete",
                payload: workflow.keyword + " ",
                category: "action",
                context: context,
                dampen: 0.9
            ))
        }
        if needle.count >= 2 {
            for link in context.links {
                push(scored(
                    query: needle,
                    fields: [link.title, link.url],
                    id: "link:\(link.id)",
                    title: link.title.isEmpty ? link.url : link.title,
                    subtitle: link.source + "  ·  " + link.url,
                    icon: "symbol:bookmark",
                    kind: "url",
                    payload: link.url,
                    category: "navigation",
                    context: context,
                    dampen: 0.88
                ))
            }
        }
        if context.preferences.clipboardEnabled, let clipQuery = argument(of: "clip", in: trimmed) ?? argument(of: "clipboard", in: trimmed) {
            let filtered = context.clips.filter { clipQuery.isEmpty || fold($0.text).contains(fold(clipQuery)) }
            for clip in filtered.prefix(8) {
                let preview = clip.text.replacingOccurrences(of: "\n", with: " ")
                found.append(make(
                    id: "clip:\(clip.id.uuidString)",
                    title: String(preview.prefix(80)),
                    subtitle: "Clipboard",
                    icon: "symbol:doc.on.clipboard",
                    kind: "clipboard",
                    payload: clip.id.uuidString,
                    category: "clipboard",
                    score: 1.4
                ))
            }
        }
        if context.preferences.onePasswordEnabled {
            for item in context.opItems {
                push(scored(
                    query: needle,
                    fields: [item.name],
                    id: "op:\(item.id)",
                    title: item.name,
                    subtitle: "1Password",
                    icon: "symbol:key",
                    kind: "copy",
                    payload: item.path,
                    category: "action",
                    context: context
                ))
            }
        }

        let ranked = dedupe(found, query: needle)
        if context.preferences.fallbackMode == "always" {
            let head = Array(ranked.prefix(resultLimit))
            return Array((head + fallbacks(for: trimmed, context: context, score: 0.2)).prefix(resultLimit + 3))
        }
        if ranked.isEmpty && context.preferences.fallbackMode != "never" {
            return cap(fallbacks(for: trimmed, context: context, score: 1), query: needle)
        }
        return cap(ranked, query: needle)
    }

    public static func wantsFiles(raw: String, preferences: Preferences) -> Bool {
        if raw.hasPrefix(" ") { return true }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if argument(of: "open", in: trimmed) != nil || argument(of: "find", in: trimmed) != nil { return true }
        if preferences.searchAllFileTypes && trimmed.count >= 3 { return true }
        let extras = preferences.extraFolders || preferences.extraDocuments || preferences.extraText || preferences.extraImages || preferences.extraArchives || preferences.extraScripts
        return extras && trimmed.count >= 3
    }

    public static func wantsDefinition(raw: String) -> String? {
        argument(of: "define", in: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func workflowResults(_ trimmed: String, context: SearchContext) -> [SearchResult]? {
        guard let match = WorkflowMatching.best(in: context.workflows, query: trimmed) else { return nil }
        let workflow = match.workflow
        let argument = match.argument
        let score = 2.0
        if let builtin = workflow.builtin {
            return builtinResults(workflow, builtin: builtin, keyword: match.keyword, argument: argument, score: score, context: context)
        }
        if workflow.actions.isEmpty {
            return [make(
                id: "wf:\(workflow.id.uuidString)",
                title: workflow.name,
                subtitle: "No actions yet",
                icon: "symbol:\(workflow.symbol)",
                kind: "text",
                payload: workflow.name,
                category: "action",
                score: score
            )]
        }
        return workflow.actions.map { action in
            let value = fillTemplate(action.value, query: argument)
            return make(
                id: "wf:\(workflow.id.uuidString):\(action.id.uuidString)",
                title: workflow.name,
                subtitle: actionSubtitle(action.kind, value: value, argument: argument),
                icon: "symbol:\(workflow.symbol)",
                kind: actionKind(action.kind),
                payload: value,
                category: "action",
                score: score
            )
        }
    }

    private static func builtinResults(_ workflow: Workflow, builtin: String, keyword: String, argument: String, score: Double, context: SearchContext) -> [SearchResult] {
        switch builtin {
        case "dev":
            return DevToys.rows(keyword: keyword, argument: argument).map { row in
                make(id: "dev:\(keyword):\(row.subtitle):\(row.payload)", title: row.title, subtitle: row.subtitle, icon: "symbol:hammer", kind: "copy", payload: row.payload, category: "action", score: score)
            }
        case "epoch":
            return Epoch.rows(argument: argument, now: context.now).map { row in
                make(id: "epoch:\(row.title)", title: row.title, subtitle: row.subtitle, icon: "symbol:clock", kind: "copy", payload: row.payload, category: "action", score: score)
            }
        case "unit":
            if let conversion = Units.convert(argument) ?? Units.convert("conv \(argument)") ?? Units.convert(argument.isEmpty ? "" : "unit \(argument)") {
                return [make(id: "unit:\(conversion.text)", title: conversion.text, subtitle: argument, icon: "symbol:ruler", kind: "calculation", payload: conversion.text, category: "general", score: score)]
            }
            return [make(id: "unit:help", title: "Unit Converter", subtitle: "Try 10 km in m", icon: "symbol:ruler", kind: "text", payload: "10 km in m, 32 f in c, 1 gb in mb", category: "general", score: score)]
        case "kill":
            let rows = context.processes.filter { argument.isEmpty || fold($0.name).contains(fold(argument)) || argument == "\($0.pid)" }
            if rows.isEmpty {
                return [make(id: "kill:none", title: "No matching processes", subtitle: "Type a name", icon: "symbol:xmark.octagon", kind: "text", payload: "", category: "action", score: score)]
            }
            return rows.prefix(12).map { proc in
                make(id: "proc:\(proc.pid)", title: proc.name, subtitle: "PID \(proc.pid)  ·  Kill", icon: "symbol:xmark.octagon", kind: "process", payload: "\(proc.pid)", category: "action", score: score)
            }
        case "windows":
            let rows = context.windows.filter { argument.isEmpty || fold($0.title + " " + $0.owner).contains(fold(argument)) }
            if rows.isEmpty {
                return [make(id: "win:none", title: "No windows", subtitle: "Open apps to switch windows", icon: "symbol:macwindow", kind: "text", payload: "", category: "navigation", score: score)]
            }
            return rows.prefix(12).map { window in
                make(id: "win:\(window.id)", title: window.title.isEmpty ? window.owner : window.title, subtitle: window.owner, icon: "symbol:macwindow", kind: "window", payload: "\(window.owner)\n\(window.title)", category: "navigation", score: score)
            }
        case "tabs":
            let pool = context.tabs + context.links.filter { $0.source.contains("History") }
            let rows = pool.filter { argument.isEmpty || fold($0.title + " " + $0.url).contains(fold(argument)) }
            if rows.isEmpty {
                return [make(id: "tabs:none", title: "No tabs or history", subtitle: "Open Chrome or Safari", icon: "symbol:globe", kind: "text", payload: "", category: "navigation", score: score)]
            }
            return rows.prefix(12).map { tab in
                make(id: "tab:\(tab.id)", title: tab.title.isEmpty ? tab.url : tab.title, subtitle: tab.source + "  ·  " + tab.url, icon: "symbol:globe", kind: "url", payload: tab.url, category: "navigation", score: score)
            }
        case "profiles":
            if context.profiles.isEmpty {
                return [make(id: "profile:none", title: "No Chrome profiles", subtitle: "Google Chrome profiles appear here", icon: "symbol:person.2", kind: "text", payload: "", category: "action", score: score)]
            }
            let rows = context.profiles.filter { argument.isEmpty || fold($0.name).contains(fold(argument)) }
            return rows.map { profile in
                make(id: "profile:\(profile.directory)", title: profile.name, subtitle: profile.directory, icon: "symbol:person.crop.circle", kind: "profile", payload: profile.directory, category: "action", score: score)
            }
        case "ui":
            let subtitle = argument.isEmpty ? "Workflow" : argument
            return [make(id: "ui:\(keyword)", title: keyword, subtitle: subtitle, icon: "symbol:cursorarrow.click.2", kind: "text", payload: "", category: "action", score: score)]
        default:
            return []
        }
    }

    private static func fileResults(query: String, context: SearchContext) -> [SearchResult] {
        if query.isEmpty {
            return [make(id: "file:hint", title: "File search", subtitle: "Type a file name", icon: "symbol:doc", kind: "text", payload: "", category: "navigation", score: 1)]
        }
        return context.files.compactMap { file in
            scored(
                query: query,
                fields: [file.name, URL(fileURLWithPath: file.path).lastPathComponent],
                id: "file:\(file.path)",
                title: file.name,
                subtitle: file.path,
                icon: "file:\(file.path)",
                kind: "file",
                payload: file.path,
                category: "navigation",
                context: context
            )
        }
    }

    private static func fallbacks(for query: String, context: SearchContext, score: Double) -> [SearchResult] {
        context.preferences.webSearches.filter { $0.enabled && $0.fallback }.map { search in
            make(
                id: "web:\(search.id):\(query)",
                title: "Search \(search.title) for ‘\(query)’",
                subtitle: context.preferences.resolvedURL(for: search, query: query),
                icon: "symbol:\(search.symbol)",
                kind: "url",
                payload: context.preferences.resolvedURL(for: search, query: query),
                category: "navigation",
                score: score
            )
        }
    }

    private static func scored(
        query: String,
        fields: [String],
        id: String,
        title: String,
        subtitle: String,
        icon: String,
        kind: String,
        payload: String,
        category: String,
        context: SearchContext,
        dampen: Double = 1,
        floor: Double? = nil
    ) -> SearchResult? {
        var score = bestFuzzyScore(query: query, fields: fields).map { $0 * dampen }
        if let floor, score == nil { score = floor }
        guard var score else { return nil }
        let key = fold(query)
        if context.preferences.topResultLatching, context.knowledge[key] == id {
            score += 0.35
        }
        return make(id: id, title: title, subtitle: subtitle, icon: icon, kind: kind, payload: payload, category: category, score: score)
    }

    private static func make(id: String, title: String, subtitle: String, icon: String, kind: String, payload: String, category: String, score: Double) -> SearchResult {
        SearchResult(id: id, title: title, subtitle: subtitle, icon: icon, kind: kind, payload: payload, category: category, score: score)
    }

    /// Apps whose names contain the query, then System Settings panes that contain it,
    /// then every other app, then the rest.
    private static func rankBand(_ item: SearchResult, query: String) -> Int {
        let folded = fold(query)
        if item.kind == "app", !folded.isEmpty, fold(item.title).contains(folded) { return 0 }
        if item.kind == "settings" { return 1 }
        if item.kind == "app" { return 2 }
        return 3
    }

    private static func dedupe(_ items: [SearchResult], query: String = "") -> [SearchResult] {
        let sorted = items.sorted { lhs, rhs in
            let lhsBand = rankBand(lhs, query: query)
            let rhsBand = rankBand(rhs, query: query)
            if lhsBand != rhsBand { return lhsBand < rhsBand }
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        var seen = Set<String>()
        return sorted.filter { seen.insert($0.id).inserted }
    }

    private static func cap(_ items: [SearchResult], query: String = "") -> [SearchResult] {
        let ranked = dedupe(items, query: query)
        let settings = ranked.filter { $0.kind == "settings" }
        guard ranked.count > resultLimit, !settings.isEmpty else {
            return Array(ranked.prefix(resultLimit))
        }
        let others = ranked.filter { $0.kind != "settings" }
        let room = max(0, resultLimit - settings.count)
        let keptOthers = Array(others.prefix(room))
        let merged = dedupe(keptOthers + settings, query: query)
        return Array(merged.prefix(resultLimit))
    }

    private static func volumeValue(_ query: String) -> Int? {
        let pattern = #"^(?:vol|volume)\s+([0-9]{1,3})$"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(query.startIndex..., in: query)
        guard let match = expression.firstMatch(in: query, range: range),
              let valueRange = Range(match.range(at: 1), in: query),
              let value = Int(query[valueRange]), (0...100).contains(value)
        else { return nil }
        return value
    }

    private static func actionKind(_ kind: WorkflowAction.Kind) -> String {
        switch kind {
        case .openURL: return "url"
        case .openApp: return "app"
        case .shell: return "shell"
        case .copy: return "copy"
        case .largeType: return "largetype"
        case .appleScript: return "applescript"
        case .terminal: return "terminal"
        }
    }

    private static func actionSubtitle(_ kind: WorkflowAction.Kind, value: String, argument: String) -> String {
        if value.trimmingCharacters(in: .whitespaces).isEmpty && argument.isEmpty {
            return "Type a query"
        }
        let label: String
        switch kind {
        case .openURL: label = "Open URL"
        case .openApp: label = "Open app"
        case .shell: label = "Run script"
        case .copy: label = "Copy"
        case .largeType: label = "Large Type"
        case .appleScript: label = "AppleScript"
        case .terminal: label = "Terminal"
        }
        return label + "  ·  " + value.replacingOccurrences(of: "\n", with: " ")
    }
}

extension Search {
    public static func mergedWebKeywords(for raw: String, context: SearchContext) -> [SearchResult] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var rows: [SearchResult] = []
        for search in context.preferences.webSearches where search.enabled {
            guard let arg = argument(of: search.keyword, in: trimmed) else { continue }
            let query = arg.isEmpty ? "" : arg
            rows.append(make(
                id: "webkw:\(search.id):\(query)",
                title: query.isEmpty ? search.title : "Search \(search.title) for ‘\(query)’",
                subtitle: query.isEmpty ? search.keyword : context.preferences.resolvedURL(for: search, query: query),
                icon: "symbol:\(search.symbol)",
                kind: query.isEmpty ? "complete" : "url",
                payload: query.isEmpty ? search.keyword + " " : context.preferences.resolvedURL(for: search, query: query),
                category: "navigation",
                score: 1.6
            ))
        }
        return rows
    }
}
