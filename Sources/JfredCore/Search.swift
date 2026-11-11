import Foundation

public enum Search {
    /// Matches kept for the launcher. The window shows a shorter viewport and scrolls.
    public static let resultLimit = 40

    public static func results(for raw: String, context: SearchContext) -> [SearchResult] {
        if raw.hasPrefix(" "), context.preferences.quickSearchEnabled {
            return cap(fileResults(query: raw.trimmingCharacters(in: .whitespacesAndNewlines), context: context), context: context)
        }
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return defaultEmptyResults(context: context)
        }
        if let forced = context.forcedResults {
            return Array(forced.prefix(12))
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !context.preferences.terminalPrefix.isEmpty, trimmed.hasPrefix(context.preferences.terminalPrefix) {
            let command = String(trimmed.dropFirst(context.preferences.terminalPrefix.count)).trimmingCharacters(in: .whitespaces)
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
        let prefs = context.preferences
        func keywordQuery(_ keyword: String, enabled: Bool) -> String? {
            let key = keyword.trimmingCharacters(in: .whitespaces)
            guard enabled, !key.isEmpty else { return nil }
            return argument(of: key, in: trimmed)
        }
        if let openQuery = keywordQuery(prefs.fileOpenKeyword, enabled: prefs.fileOpenEnabled)
            ?? keywordQuery(prefs.fileFindKeyword, enabled: prefs.fileFindEnabled) {
            let rows = fileResults(query: openQuery, context: context)
            return Array(rows.prefix(max(1, prefs.fileSearchMax)))
        }
        if let inside = keywordQuery(prefs.fileInsideKeyword, enabled: prefs.fileInsideEnabled), let spotlight = context.spotlight {
            return spotlightFileResults(spotlight(inside, false), context: context, limit: prefs.fileSearchMax)
        }
        if let tags = keywordQuery(prefs.fileTagsKeyword, enabled: prefs.fileTagsEnabled), let spotlight = context.spotlight {
            return spotlightFileResults(spotlight(tags, true), context: context, limit: prefs.fileSearchMax)
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

        let webHits = mergedWebKeywords(for: trimmed, context: context)
        if !webHits.isEmpty {
            return cap(webHits, context: context)
        }
        if let viewer = clipboardViewerResults(for: trimmed, context: context) {
            return viewer
        }

        var found: [SearchResult] = []
        if context.preferences.calculatorEnabled, Calculator.allows(trimmed, advanced: context.preferences.calculatorAdvanced), let value = Calculator.evaluate(trimmed) {
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
        if context.preferences.dictionaryEnabled, context.preferences.dictionaryDefineEnabled, let word = argument(of: context.preferences.dictionaryDefineKeyword, in: trimmed) {
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
        // Match against prepared keys first and build a row only for a hit.
        var index = context.index ?? SearchIndex()
        index.refresh(for: context)
        let query = MatchQuery(needle)

        for (app, entry) in zip(index.apps.records, index.apps.entries) where entry.included {
            guard let match = keptMatch(query, entry.keys) else { continue }
            found.append(make(
                id: "app:\(app.path)",
                title: app.name,
                subtitle: app.path,
                icon: "file:\(app.path)",
                kind: "app",
                payload: app.path,
                category: "general",
                score: match.score,
                tier: match.tier
            ))
        }
        for (place, key) in zip(index.places.records, index.places.entries) {
            guard let match = keptMatch(query, [key]) else { continue }
            found.append(make(
                id: "place:\(place.id)",
                title: place.name,
                subtitle: place.id == "computer" ? "Open Computer in Finder" : place.path,
                icon: place.path.isEmpty ? "symbol:desktopcomputer" : "file:\(place.path)",
                kind: "place",
                payload: place.id,
                category: "navigation",
                score: match.score,
                tier: match.tier
            ))
        }
        if context.preferences.systemSettingsEnabled, !query.folded.isEmpty {
            for (setting, key) in zip(index.settings.records, index.settings.entries) where key.folded.contains(query.folded) {
                guard let match = keptMatch(query, [key]) else { continue }
                found.append(make(
                    id: "set:\(setting.id)",
                    title: setting.name,
                    subtitle: "System Settings",
                    icon: "symbol:gearshape",
                    kind: "settings",
                    payload: setting.url,
                    category: "general",
                    score: match.score,
                    tier: match.tier
                ))
            }
        }
        if context.preferences.snippetsEnabled {
            for (snippet, entry) in zip(index.snippets.records, index.snippets.entries) {
                let snippetKeys: [MatchKey]
                switch context.preferences.snippetMatching {
                case "name": snippetKeys = [entry.name]
                case "keyword": snippetKeys = [entry.keyword]
                default: snippetKeys = [entry.name, entry.keyword]
                }
                let floor: Double? = query.folded == entry.keyword.folded ? 1.55 : nil
                guard let match = keptMatch(query, snippetKeys, floor: floor) else { continue }
                let snippetSubtitle = context.preferences.snippetShowKeywordInResult
                    ? snippet.keyword + "  ·  " + snippet.text.replacingOccurrences(of: "\n", with: " ")
                    : snippet.text.replacingOccurrences(of: "\n", with: " ")
                found.append(make(
                    id: "snip:\(snippet.id.uuidString)",
                    title: snippet.name,
                    subtitle: snippetSubtitle,
                    icon: "symbol:text.quote",
                    kind: "snippet",
                    payload: snippet.id.uuidString,
                    category: "expansion",
                    score: match.score,
                    tier: match.tier
                ))
            }
        }
        for (command, entry) in zip(SystemCommand.all, SearchIndex.commands) {
            if context.preferences.systemDisabled.contains(command.id) { continue }
            if command.id == "ejectall", !context.preferences.ejectAllEnabled { continue }
            let commandKeys: [MatchKey]
            if let custom = context.preferences.systemKeywords[command.id] {
                commandKeys = [index.systemKeywords[command.id] ?? MatchKey(custom), entry.title]
            } else {
                commandKeys = entry.titleAndKeywords
            }
            guard let match = keptMatch(query, commandKeys) else { continue }
            found.append(make(
                id: "sys:\(command.id)",
                title: command.title,
                subtitle: command.subtitle,
                icon: "symbol:\(command.symbol)",
                kind: "system",
                payload: command.id,
                category: command.category,
                score: match.score,
                tier: match.tier
            ))
        }
        for (workflow, entry) in zip(index.workflows.records, index.workflows.entries) where workflow.enabled {
            guard let match = keptMatch(query, entry.keys) else { continue }
            // Icon lookup checks the disk; do it only for rows that match.
            found.append(make(
                id: "complete:\(workflow.id.uuidString)",
                title: workflow.name,
                subtitle: entry.keyword,
                icon: workflow.resolvedIcon().resource,
                kind: "complete",
                payload: entry.keyword + " ",
                category: "action",
                score: match.score,
                tier: match.tier
            ))
        }
        let bookmarkMode = context.preferences.bookmarkResultMode
        var bookmarkNeedle = needle
        var showBookmarks = bookmarkMode == "default"
        if bookmarkMode == "keyword" {
            let keyword = context.preferences.bookmarkKeyword.lowercased()
            if !keyword.isEmpty, needle.lowercased().hasPrefix(keyword + " ") {
                showBookmarks = true
                bookmarkNeedle = String(needle.dropFirst(keyword.count + 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        if showBookmarks, bookmarkNeedle.count >= 2 {
            let bookmarkQuery = bookmarkNeedle == needle ? query : MatchQuery(bookmarkNeedle)
            for (link, keys) in zip(index.links.records, index.links.entries) {
                guard let match = keptMatch(bookmarkQuery, keys, dampen: 0.88) else { continue }
                found.append(make(
                    id: "link:\(link.id)",
                    title: link.title.isEmpty ? link.url : link.title,
                    subtitle: link.source + "  ·  " + link.url,
                    icon: "symbol:bookmark",
                    kind: "url",
                    payload: link.url,
                    category: "navigation",
                    score: match.score,
                    tier: match.tier
                ))
            }
        }
        if context.preferences.clipboardEnabled, context.preferences.clipboardClearKeywordEnabled,
           let cleared = clearKeywordQuery(trimmed, keyword: context.preferences.clipboardClearKeyword) {
            let title = cleared == nil ? "Clear All Clipboard History" : "Clear Clipboard History (last \(cleared!) minutes)"
            found.append(make(
                id: "clipclear:\(cleared.map(String.init) ?? "all")",
                title: title,
                subtitle: "Clear Jfred's clipboard history",
                icon: "symbol:trash",
                kind: "clipclear",
                payload: cleared.map(String.init) ?? "all",
                category: "clipboard",
                score: 2
            ))
        }
        if context.preferences.onePasswordEnabled {
            for (item, key) in zip(index.opItems.records, index.opItems.entries) {
                guard let match = keptMatch(query, [key]) else { continue }
                found.append(make(
                    id: "op:\(item.id)",
                    title: item.name,
                    subtitle: "1Password",
                    icon: "symbol:key",
                    kind: "copy",
                    payload: item.path,
                    category: "action",
                    score: match.score,
                    tier: match.tier
                ))
            }
        }

        let ranked = sortRows(rankRows(found, query: needle, context: context))
        if context.preferences.fallbackMode == "always" {
            let head = ranked.prefix(resultLimit).map(\.row)
            return Array((head + fallbacks(for: trimmed, context: context, score: 0.2)).prefix(resultLimit + 3))
        }
        if ranked.isEmpty && context.preferences.fallbackMode != "never" {
            return cap(fallbacks(for: trimmed, context: context, score: 1), query: needle, context: context)
        }
        return cap(ranked: ranked)
    }

    public static func wantsFiles(raw: String, preferences: Preferences) -> Bool {
        if raw.hasPrefix(" "), preferences.quickSearchEnabled { return true }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let keywords = [
            (preferences.fileOpenKeyword, preferences.fileOpenEnabled),
            (preferences.fileFindKeyword, preferences.fileFindEnabled),
        ]
        for (keyword, enabled) in keywords where enabled && !keyword.isEmpty {
            if argument(of: keyword, in: trimmed) != nil { return true }
        }
        if preferences.searchAllFileTypes && trimmed.count >= 3 { return true }
        let extras = preferences.extraFolders || preferences.extraDocuments || preferences.extraText || preferences.extraImages || preferences.extraArchives || preferences.extraScripts
        return extras && trimmed.count >= 3
    }

    /// File-name and Spotlight queries. Their rows replace the app ranking, so the
    /// launcher must not publish that ranking while the lookup is still running.
    public static func exclusiveSlowQuery(raw: String, preferences: Preferences) -> Bool {
        if raw.hasPrefix(" "), preferences.quickSearchEnabled { return true }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let keywords = [
            (preferences.fileOpenKeyword, preferences.fileOpenEnabled),
            (preferences.fileFindKeyword, preferences.fileFindEnabled),
            (preferences.fileInsideKeyword, preferences.fileInsideEnabled),
            (preferences.fileTagsKeyword, preferences.fileTagsEnabled),
        ]
        for (keyword, enabled) in keywords {
            let key = keyword.trimmingCharacters(in: .whitespaces)
            guard enabled, !key.isEmpty else { continue }
            if argument(of: key, in: trimmed) != nil { return true }
        }
        return false
    }

    public static func wantsDefinition(raw: String) -> String? {
        argument(of: "define", in: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func fileResults(query: String, context: SearchContext) -> [SearchResult] {
        if query.isEmpty {
            return [make(id: "file:hint", title: "File search", subtitle: "Type a file name", icon: "symbol:doc", kind: "text", payload: "", category: "navigation", score: 1)]
        }
        let hidden = Set(context.preferences.hiddenFileTypes)
        let prepared = MatchQuery(query)
        return context.files.filter { !isHiddenFile($0.path, hiddenTypes: hidden) }.compactMap { file in
            let keys = [MatchKey(file.name), MatchKey(URL(fileURLWithPath: file.path).lastPathComponent)]
            guard let match = keptMatch(prepared, keys) else { return nil }
            return make(
                id: "file:\(file.path)",
                title: file.name,
                subtitle: file.path,
                icon: context.preferences.fileUseTypeIconsForExternal && file.path.hasPrefix("/Volumes/") ? "symbol:doc" : "file:\(file.path)",
                kind: "file",
                payload: file.path,
                category: "navigation",
                score: match.score,
                tier: match.tier
            )
        }
    }

    private static let hiddenExtensions: [String: Set<String>] = [
        "Emails": ["eml", "msg", "email"],
        "Contacts": ["vcf"],
        "Calendar": ["ics"],
        "Bookmarks": ["webloc", "url", "plist"],
        "Images": ["png", "jpg", "jpeg", "gif", "heic", "tiff", "bmp", "webp", "svg"],
        "Messages": ["ichat"],
        "Music": ["mp3", "m4a", "aac", "flac", "wav", "aiff", "ogg"],
        "Plist files": ["plist"],
        "Source files": ["swift", "c", "h", "m", "mm", "cpp", "hpp", "py", "js", "ts", "jsx", "tsx", "go", "rs", "java", "kt", "rb", "sh", "zsh", "fish", "lua", "php"],
    ]

    private static func isHiddenFile(_ path: String, hiddenTypes: Set<String>) -> Bool {
        guard !hiddenTypes.isEmpty else { return false }
        let ext = (path as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        for type in hiddenTypes where hiddenExtensions[type]?.contains(ext) == true { return true }
        return false
    }

    private static func spotlightFileResults(_ records: [AppRecord], context: SearchContext, limit: Int) -> [SearchResult] {
        records.prefix(max(1, limit)).map { record in
            make(
                id: "file:\(record.path)",
                title: record.name,
                subtitle: record.path,
                icon: "file:\(record.path)",
                kind: "file",
                payload: record.path,
                category: "navigation",
                score: 2
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

    /// Best match across the keys, kept only when the launcher shows it.
    private static func keptMatch(_ query: MatchQuery, _ keys: [MatchKey], dampen: Double = 1, floor: Double? = nil) -> FieldMatch? {
        // Rows keep tiers 0-2, so the matcher can skip the substring and fuzzy
        // steps. With a floor, any match (even tier 3 or 4) must still block the
        // floor, so match every tier.
        var match = bestFieldMatch(query: query, keys: keys, maxTier: floor == nil ? 2 : 4)
        if var found = match {
            found.score *= dampen
            match = found
        } else if let floor {
            match = FieldMatch(tier: 0, score: floor)
        }
        // Alfred keeps a query to a name or word prefix. A mid-word
        // substring ("Sharing" for "ha") or a fuzzy hit ("Hostpane") stays out.
        guard let match, match.tier <= 2 else { return nil }
        return match
    }

    private static func make(id: String, title: String, subtitle: String, icon: String, kind: String, payload: String, category: String, score: Double, tier: Int = 0, badge: String = "", badgeName: String = "") -> SearchResult {
        SearchResult(id: id, title: title, subtitle: subtitle, icon: icon, kind: kind, payload: payload, category: category, score: score, tier: tier, badge: badge, badgeName: badgeName)
    }

    /// Background helpers under CoreServices are not launcher apps.
    /// `/System/Library/CoreServices/Applications` and Finder stay.
    static func includeApp(path: String) -> Bool {
        let folded = fold(path)
        let marker = "/system/library/coreservices/"
        guard let range = folded.range(of: marker) else { return true }
        let rest = folded[range.upperBound...]
        if rest.hasPrefix("applications/") { return true }
        if rest == "finder.app" || rest.hasPrefix("finder.app/") { return true }
        return false
    }

    /// `/Applications` apps whose names contain the query, then other apps that contain it,
    /// then System Settings panes, then remaining matches.
    private static func rankBand(_ item: SearchResult, foldedQuery: String) -> Int {
        guard item.kind == "app" else { return item.kind == "settings" ? 2 : 5 }
        let nameHit = !foldedQuery.isEmpty && fold(item.title).contains(foldedQuery)
        let applications = item.payload.range(of: "/Applications/", options: [.anchored, .caseInsensitive]) != nil
        if applications && nameHit { return 0 }
        if nameHit { return 1 }
        if applications { return 3 }
        return 4
    }

    /// A row with its sort keys, computed once instead of in every comparison.
    private struct RankedRow {
        let row: SearchResult
        let band: Int
        let latched: Bool
        let frecency: Double
        let total: Double
    }

    private static func rankRows(_ items: [SearchResult], query: String, context: SearchContext?) -> [RankedRow] {
        let folded = fold(query)
        let latched = context?.preferences.topResultLatching == true ? context?.knowledge[folded] : nil
        let now = context?.now ?? Date()
        return items.map { item in
            let stat = context?.selections[item.id]
            let frecency = selectionFrecency(count: stat?.count ?? 0, lastSelected: stat?.lastSelected ?? .distantPast, now: now)
            return RankedRow(
                row: item,
                band: rankBand(item, foldedQuery: folded),
                latched: item.id == latched,
                frecency: frecency,
                total: item.score + min(0.45, frecency * 0.08)
            )
        }
    }

    /// Band, the latched top result, match tier, score plus frecency, frecency,
    /// then title. Drops repeated ids after sorting.
    private static func sortRows(_ rows: [RankedRow]) -> [RankedRow] {
        let sorted = rows.sorted { lhs, rhs in
            if lhs.band != rhs.band { return lhs.band < rhs.band }
            if lhs.latched != rhs.latched { return lhs.latched }
            if lhs.row.tier != rhs.row.tier { return lhs.row.tier < rhs.row.tier }
            if abs(lhs.total - rhs.total) > 0.0001 { return lhs.total > rhs.total }
            if lhs.frecency != rhs.frecency { return lhs.frecency > rhs.frecency }
            return lhs.row.title.localizedCaseInsensitiveCompare(rhs.row.title) == .orderedAscending
        }
        var seen = Set<String>()
        return sorted.filter { seen.insert($0.row.id).inserted }
    }

    /// Recent apps, clipboard clips and usage-backed rows shown for an empty query.
    private static func defaultEmptyResults(context: SearchContext) -> [SearchResult] {
        var rows: [SearchResult] = []
        let now = context.now
        let rankedApps = context.apps
            .filter { includeApp(path: $0.path) }
            .compactMap { app -> (AppRecord, Double)? in
                let id = "app:\(app.path)"
                guard let stat = context.selections[id], stat.count > 0 else { return nil }
                return (app, selectionFrecency(count: stat.count, lastSelected: stat.lastSelected, now: now))
            }
            .sorted { $0.1 > $1.1 }
            .prefix(8)
        for (app, freq) in rankedApps {
            rows.append(make(
                id: "app:\(app.path)",
                title: app.name,
                subtitle: app.path,
                icon: "file:\(app.path)",
                kind: "app",
                payload: app.path,
                category: "general",
                score: 1.2 + min(0.4, freq * 0.05)
            ))
        }
        if context.preferences.clipboardEnabled {
            for clip in context.clips.prefix(5) {
                let kind = clip.kind ?? "text"
                let row = ClipboardText.row(
                    text: clip.text,
                    fallback: kind == "image" ? "Clipboard image" : (kind == "file" ? "Clipboard files" : "Clipboard")
                )
                let icon: String
                if kind == "image", let file = clip.imageFile, !file.isEmpty {
                    icon = "clipimage:\(file)"
                } else if kind == "file" {
                    icon = "symbol:doc.on.doc"
                } else {
                    icon = "symbol:doc.on.clipboard"
                }
                rows.append(make(
                    id: "clip:\(clip.id.uuidString)",
                    title: row.title,
                    subtitle: "Clipboard History",
                    icon: icon,
                    kind: "clipboard",
                    payload: clip.id.uuidString,
                    category: "clipboard",
                    score: 1.05
                ))
            }
        }
        if rows.isEmpty {
            for app in context.apps.prefix(8) where includeApp(path: app.path) {
                rows.append(make(
                    id: "app:\(app.path)",
                    title: app.name,
                    subtitle: app.path,
                    icon: "file:\(app.path)",
                    kind: "app",
                    payload: app.path,
                    category: "general",
                    score: 1
                ))
            }
        }
        return Array(rows.prefix(resultLimit))
    }

    private static func cap(_ items: [SearchResult], query: String = "", context: SearchContext? = nil) -> [SearchResult] {
        cap(ranked: rankRows(items, query: query, context: context))
    }

    private static func cap(ranked rows: [RankedRow]) -> [SearchResult] {
        let ranked = sortRows(rows)
        let settings = ranked.filter { $0.row.kind == "settings" }
        guard ranked.count > resultLimit, !settings.isEmpty else {
            return ranked.prefix(resultLimit).map(\.row)
        }
        let others = ranked.filter { $0.row.kind != "settings" }
        let room = max(0, resultLimit - settings.count)
        let keptOthers = Array(others.prefix(room))
        let merged = sortRows(keptOthers + settings)
        return merged.prefix(resultLimit).map(\.row)
    }

    /// Clipboard viewer is its own result list. Newest clips stay first.
    private static func clipboardViewerResults(for trimmed: String, context: SearchContext) -> [SearchResult]? {
        guard context.preferences.clipboardEnabled else { return nil }
        guard let clipQuery = argument(of: context.preferences.clipboardViewerKeyword, in: trimmed) ?? argument(of: "clip", in: trimmed) else { return nil }
        var rows: [SearchResult] = []
        if context.preferences.clipboardSnippetsAtTop, clipQuery.isEmpty {
            rows.append(make(
                id: "snippets:all",
                title: "All Snippets",
                subtitle: "Browse snippets in the launcher",
                icon: "symbol:text.quote",
                kind: "snippets",
                payload: "",
                category: "expansion",
                score: 2
            ))
        }
        var snippets: [SearchResult] = []
        if context.preferences.clipboardSnippetsWhenSearching, !clipQuery.isEmpty {
            for snippet in context.snippets {
                let hay = snippet.name + " " + snippet.keyword + " " + snippet.text
                guard clipQuery.isEmpty || fold(hay).contains(fold(clipQuery)) else { continue }
                snippets.append(make(
                    id: "snippet:\(snippet.id.uuidString):clip",
                    title: snippet.name,
                    subtitle: snippet.keyword + "  ·  " + snippet.text.replacingOccurrences(of: "\n", with: " "),
                    icon: "symbol:text.quote",
                    kind: "snippet",
                    payload: snippet.id.uuidString,
                    category: "expansion",
                    score: context.preferences.clipboardSnippetsAtTop ? 1.8 : 1.38
                ))
            }
        }
        let filtered = context.clips.filter { clipQuery.isEmpty || fold($0.text).contains(fold(clipQuery)) }
        var clips: [SearchResult] = []
        for clip in filtered {
            let kind = clip.kind ?? "text"
            let title: String
            let subtitle: String
            let icon: String
            switch kind {
            case "image":
                title = ClipboardPreview.imageListTitle(path: clip.imageFile)
                if !clip.text.isEmpty, clip.text != "Image" {
                    subtitle = ClipboardText.row(text: clip.text, fallback: "Clipboard image").title
                } else {
                    subtitle = "Clipboard image"
                }
                icon = clip.imageFile.map { "clipimage:\($0)" } ?? "symbol:photo"
            case "file":
                let paths = clip.filePaths ?? []
                title = ClipboardPreview.fileListTitle(paths: paths)
                subtitle = paths.map { ClipboardPreview.abbreviatedPath($0) }.joined(separator: "  ·  ")
                icon = paths.first.map { "file:\($0)" } ?? "symbol:doc"
            default:
                let row = ClipboardText.row(text: clip.text, fallback: "Clipboard")
                title = row.title
                subtitle = row.subtitle
                icon = "symbol:doc.on.clipboard"
            }
            let source = clip.sourcePath ?? ""
            clips.append(make(
                id: "clip:\(clip.id.uuidString)",
                title: title,
                subtitle: subtitle,
                icon: icon,
                kind: "clipboard",
                payload: clip.id.uuidString,
                category: "clipboard",
                score: 1.4,
                badge: source.isEmpty ? "" : "file:\(source)",
                badgeName: clip.sourceName ?? ""
            ))
        }
        if context.preferences.clipboardSnippetsAtTop {
            rows.append(contentsOf: snippets)
            rows.append(contentsOf: clips)
        } else {
            rows.append(contentsOf: clips)
            rows.append(contentsOf: snippets)
        }
        if rows.isEmpty {
            rows.append(make(
                id: "clipboard:empty",
                title: "No clipboard history",
                subtitle: "Copies show up here after you copy something",
                icon: "symbol:doc.on.clipboard",
                kind: "text",
                payload: "",
                category: "clipboard",
                score: 1
            ))
        }
        return Array(rows.prefix(resultLimit))
    }

    private static func clearKeywordQuery(_ query: String, keyword: String) -> Int?? {
        let key = keyword.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        let folded = fold(query.trimmingCharacters(in: .whitespaces))
        guard folded == fold(key) || folded.hasPrefix(fold(key) + " ") else { return nil }
        let rest = query.trimmingCharacters(in: .whitespaces).dropFirst(key.count).trimmingCharacters(in: .whitespaces)
        if rest.isEmpty { return .some(nil) }
        if let minutes = Int(rest), minutes == 5 || minutes == 15 { return .some(minutes) }
        return nil
    }

    private static let volumePattern = try? NSRegularExpression(pattern: #"^(?:vol|volume)\s+([0-9]{1,3})$"#, options: [.caseInsensitive])

    private static func volumeValue(_ query: String) -> Int? {
        guard let expression = volumePattern else { return nil }
        let range = NSRange(query.startIndex..., in: query)
        guard let match = expression.firstMatch(in: query, range: range),
              let valueRange = Range(match.range(at: 1), in: query),
              let value = Int(query[valueRange]), (0...100).contains(value)
        else { return nil }
        return value
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
