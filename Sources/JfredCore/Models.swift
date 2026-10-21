import Foundation

public struct Hotkey: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var modifiers: UInt

    public init(keyCode: UInt16, modifiers: UInt) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let screenshotDefault = Hotkey(keyCode: 49, modifiers: Hotkey.controlOptionShiftCommand)
    public static let fallback = Hotkey(keyCode: 49, modifiers: Hotkey.controlOption)

    public static let command: UInt = 1 << 20
    public static let shift: UInt = 1 << 17
    public static let option: UInt = 1 << 19
    public static let control: UInt = 1 << 18
    public static let controlOptionShiftCommand: UInt = command | shift | option | control
    public static let controlOption: UInt = control | option

    public var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if modifiers & Hotkey.command != 0 { mask |= 256 }
        if modifiers & Hotkey.shift != 0 { mask |= 512 }
        if modifiers & Hotkey.option != 0 { mask |= 2048 }
        if modifiers & Hotkey.control != 0 { mask |= 4096 }
        return mask
    }
}

public struct WebSearch: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var keyword: String
    public var urlTemplate: String
    public var enabled: Bool
    public var fallback: Bool
    public var symbol: String

    public init(id: String, title: String, keyword: String, urlTemplate: String, enabled: Bool, fallback: Bool, symbol: String) {
        self.id = id
        self.title = title
        self.keyword = keyword
        self.urlTemplate = urlTemplate
        self.enabled = enabled
        self.fallback = fallback
        self.symbol = symbol
    }

    public static let defaults: [WebSearch] = [
        WebSearch(id: "google", title: "Google", keyword: "g", urlTemplate: "https://{google}/search?q={query}", enabled: true, fallback: true, symbol: "magnifyingglass"),
        WebSearch(id: "amazon", title: "Amazon", keyword: "amazon", urlTemplate: "https://{amazon}/s?k={query}", enabled: true, fallback: true, symbol: "cart"),
        WebSearch(id: "wiki", title: "Wikipedia", keyword: "wiki", urlTemplate: "https://en.wikipedia.org/wiki/Special:Search?search={query}", enabled: true, fallback: true, symbol: "book"),
        WebSearch(id: "youtube", title: "YouTube", keyword: "yt", urlTemplate: "https://www.youtube.com/results?search_query={query}", enabled: true, fallback: false, symbol: "play.rectangle"),
        WebSearch(id: "maps", title: "Maps", keyword: "maps", urlTemplate: "https://maps.apple.com/?q={query}", enabled: true, fallback: false, symbol: "map"),
        WebSearch(id: "github", title: "GitHub", keyword: "gh", urlTemplate: "https://github.com/search?q={query}", enabled: true, fallback: false, symbol: "chevron.left.forwardslash.chevron.right"),
    ]
}

public struct Preferences: Codable, Equatable, Sendable {
    public var launchAtLogin: Bool
    public var hotkey: Hotkey
    public var location: String
    public var useDotCom: Bool
    public var systemSettingsEnabled: Bool
    public var extraFolders: Bool
    public var extraDocuments: Bool
    public var extraText: Bool
    public var extraImages: Bool
    public var extraArchives: Bool
    public var extraScripts: Bool
    public var searchAllFileTypes: Bool
    public var scopeApplications: Bool
    public var scopeHome: Bool
    public var scopePaths: [String]
    public var includeSystemApps: Bool
    public var includeUserApps: Bool
    public var includePreferencePanes: Bool
    public var fallbackMode: String
    public var webSearches: [WebSearch]
    public var themeID: String
    public var storeTypedQuery: Bool
    public var showLatestQuery: Bool
    public var topResultLatching: Bool
    public var removeNotificationWhenClicked: Bool
    public var showNotificationIcons: Bool
    public var useHTTPProxy: Bool
    public var selectionHotkeyMode: String
    public var forceKeyboard: String
    public var modifierControl: String
    public var modifierOption: String
    public var modifierCommand: String
    public var syncFolder: String
    public var snippetsEnabled: Bool
    public var clipboardEnabled: Bool
    public var clipboardLimit: Int
    public var calculatorEnabled: Bool
    public var dictionaryEnabled: Bool
    public var onePasswordEnabled: Bool
    public var largeTypeSize: Double
    public var largeTypeFont: String
    public var quickLookEnabled: Bool
    public var terminalApp: String
    public var fileSearchMax: Int
    public var remoteEnabled: Bool
    public var remoteLocalOnly: Bool
    public var remoteToken: String
    public var remotePort: Int
    public var autoUpdateCheck: String
    public var recentQueries: [String]
    public var lastQueryDate: Date?
    public var newsletterEmail: String
    public var safariBookmarks: Bool
    public var chromeBookmarks: Bool
    public var fileBufferEnabled: Bool

    public static let defaultScope: [String] = [
        "/Applications/Xcode.app/Contents/Applications",
        "/Developer/Applications",
        "/Library/PreferencePanes",
        "/opt/homebrew/Cellar",
        "/System/Library/CoreServices/Applications",
        "/System/Library/PreferencePanes",
        "/usr/local/Cellar",
        "~/Library/Caches/Metadata",
        "~/Library/CloudStorage",
        "~/Library/Mobile Documents",
        "~/Library/PreferencePanes",
    ]

    public static let locations: [String] = [
        "International", "United States", "United Kingdom", "Australia", "Canada",
        "Germany", "France", "Japan", "China", "Hong Kong", "Taiwan", "Singapore",
        "India", "Brazil", "Spain", "Italy", "Netherlands", "Sweden", "Switzerland",
        "Ireland", "New Zealand", "South Korea",
    ]

    public init() {
        launchAtLogin = true
        hotkey = Hotkey(keyCode: 49, modifiers: Hotkey.command)
        location = "International"
        useDotCom = true
        systemSettingsEnabled = true
        extraFolders = false
        extraDocuments = false
        extraText = false
        extraImages = false
        extraArchives = false
        extraScripts = false
        searchAllFileTypes = false
        scopeApplications = true
        scopeHome = true
        scopePaths = Preferences.defaultScope
        includeSystemApps = true
        includeUserApps = true
        includePreferencePanes = true
        fallbackMode = "none"
        webSearches = WebSearch.defaults
        themeID = "modern"
        storeTypedQuery = true
        showLatestQuery = false
        topResultLatching = true
        removeNotificationWhenClicked = true
        showNotificationIcons = true
        useHTTPProxy = false
        selectionHotkeyMode = "leave"
        forceKeyboard = ""
        modifierControl = "web"
        modifierOption = "finder"
        modifierCommand = "reveal"
        syncFolder = ""
        snippetsEnabled = true
        clipboardEnabled = true
        clipboardLimit = 250
        calculatorEnabled = true
        dictionaryEnabled = true
        onePasswordEnabled = false
        largeTypeSize = 96
        largeTypeFont = "System"
        quickLookEnabled = true
        terminalApp = "iTerm"
        fileSearchMax = 20
        remoteEnabled = false
        remoteLocalOnly = true
        remoteToken = UUID().uuidString.prefix(8).lowercased() + UUID().uuidString.prefix(4).lowercased()
        remotePort = 8910
        autoUpdateCheck = "updates"
        recentQueries = []
        lastQueryDate = nil
        newsletterEmail = ""
        safariBookmarks = true
        chromeBookmarks = true
        fileBufferEnabled = true
    }

    public var googleHost: String {
        if useDotCom { return "www.google.com" }
        switch location {
        case "United Kingdom": return "www.google.co.uk"
        case "Australia": return "www.google.com.au"
        case "Canada": return "www.google.ca"
        case "Germany": return "www.google.de"
        case "France": return "www.google.fr"
        case "Japan": return "www.google.co.jp"
        case "Hong Kong": return "www.google.com.hk"
        case "Taiwan": return "www.google.com.tw"
        case "India": return "www.google.co.in"
        case "Brazil": return "www.google.com.br"
        case "Spain": return "www.google.es"
        case "Italy": return "www.google.it"
        case "Netherlands": return "www.google.nl"
        case "Sweden": return "www.google.se"
        case "Switzerland": return "www.google.ch"
        case "Ireland": return "www.google.ie"
        case "New Zealand": return "www.google.co.nz"
        case "South Korea": return "www.google.co.kr"
        default: return "www.google.com"
        }
    }

    public var amazonHost: String {
        switch location {
        case "United Kingdom", "Ireland": return "www.amazon.co.uk"
        case "Germany", "Austria": return "www.amazon.de"
        case "France": return "www.amazon.fr"
        case "Japan": return "www.amazon.co.jp"
        case "Canada": return "www.amazon.ca"
        case "Australia": return "www.amazon.com.au"
        case "Italy": return "www.amazon.it"
        case "Spain": return "www.amazon.es"
        case "Netherlands": return "www.amazon.nl"
        case "Sweden": return "www.amazon.se"
        case "Brazil": return "www.amazon.com.br"
        case "India": return "www.amazon.in"
        case "China": return "www.amazon.cn"
        default: return "www.amazon.com"
        }
    }

    public func resolvedURL(for search: WebSearch, query: String) -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return search.urlTemplate
            .replacingOccurrences(of: "{query}", with: encoded)
            .replacingOccurrences(of: "{google}", with: googleHost)
            .replacingOccurrences(of: "{amazon}", with: amazonHost)
    }
}

public struct WorkflowAction: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case openURL
        case openApp
        case shell
        case copy
        case largeType
        case appleScript
        case terminal
    }

    public var id: UUID
    public var kind: Kind
    public var value: String

    public init(id: UUID = UUID(), kind: Kind, value: String) {
        self.id = id
        self.kind = kind
        self.value = value
    }
}

public struct Workflow: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var keyword: String
    public var author: String
    public var symbol: String
    public var tint: String
    public var enabled: Bool
    public var builtin: String?
    public var actions: [WorkflowAction]
    public var hotkey: Hotkey?

    public init(
        id: UUID = UUID(),
        name: String,
        keyword: String,
        author: String,
        symbol: String,
        tint: String,
        enabled: Bool = true,
        builtin: String? = nil,
        actions: [WorkflowAction] = [],
        hotkey: Hotkey? = nil
    ) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.author = author
        self.symbol = symbol
        self.tint = tint
        self.enabled = enabled
        self.builtin = builtin
        self.actions = actions
        self.hotkey = hotkey
    }
}

public struct Snippet: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var keyword: String
    public var text: String
    public var autoExpand: Bool

    public init(id: UUID = UUID(), name: String, keyword: String, text: String, autoExpand: Bool = true) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.text = text
        self.autoExpand = autoExpand
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, keyword, text, autoExpand
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        keyword = try container.decode(String.self, forKey: .keyword)
        text = try container.decode(String.self, forKey: .text)
        autoExpand = try container.decodeIfPresent(Bool.self, forKey: .autoExpand) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(keyword, forKey: .keyword)
        try container.encode(text, forKey: .text)
        try container.encode(autoExpand, forKey: .autoExpand)
    }
}

public struct ClipItem: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var text: String
    public var date: Date

    public init(id: UUID = UUID(), text: String, date: Date) {
        self.id = id
        self.text = text
        self.date = date
    }
}

public struct UsageEvent: Codable, Equatable, Sendable {
    public var date: Date
    public var category: String

    public init(date: Date, category: String) {
        self.date = date
        self.category = category
    }

    public static let categories = ["general", "expansion", "clipboard", "navigation", "action", "music", "remote", "hotkeys"]
}

public struct AppRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var path: String

    public init(id: String, name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }
}

public struct SettingRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var url: String

    public init(id: String, name: String, url: String) {
        self.id = id
        self.name = name
        self.url = url
    }
}

public struct LinkRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var url: String
    public var source: String

    public init(id: String, title: String, url: String, source: String) {
        self.id = id
        self.title = title
        self.url = url
        self.source = source
    }
}

public struct ContactRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var email: String
    public var phone: String

    public init(id: String, name: String, email: String, phone: String) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
    }
}

public struct WindowInfo: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var owner: String
    public var pid: Int32

    public init(id: String, title: String, owner: String, pid: Int32) {
        self.id = id
        self.title = title
        self.owner = owner
        self.pid = pid
    }
}

public struct ProcInfo: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var pid: Int32
    public var name: String

    public init(pid: Int32, name: String) {
        self.pid = pid
        self.name = name
        self.id = "\(pid)"
    }
}

public struct ProfileInfo: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var directory: String

    public init(id: String, name: String, directory: String) {
        self.id = id
        self.name = name
        self.directory = directory
    }
}

public struct SelectionStat: Codable, Equatable, Sendable {
    public var count: Int
    public var lastSelected: Date

    public init(count: Int, lastSelected: Date) {
        self.count = count
        self.lastSelected = lastSelected
    }
}

public struct SearchResult: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var icon: String
    public var kind: String
    public var payload: String
    public var category: String
    public var score: Double
    /// Match quality. Lower is better: exact, prefix, word prefix, substring, fuzzy.
    public var tier: Int

    public init(id: String, title: String, subtitle: String, icon: String, kind: String, payload: String, category: String, score: Double, tier: Int = 0) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.kind = kind
        self.payload = payload
        self.category = category
        self.score = score
        self.tier = tier
    }
}

public struct SearchContext: Sendable {
    public var preferences: Preferences
    public var workflows: [Workflow]
    public var snippets: [Snippet]
    public var apps: [AppRecord]
    public var places: [AppRecord]
    public var settings: [SettingRecord]
    public var links: [LinkRecord]
    public var contacts: [ContactRecord]
    public var clips: [ClipItem]
    public var files: [AppRecord]
    public var windows: [WindowInfo]
    public var processes: [ProcInfo]
    public var tabs: [LinkRecord]
    public var profiles: [ProfileInfo]
    public var definition: String?
    public var opItems: [AppRecord]
    public var knowledge: [String: String]
    public var selections: [String: SelectionStat]
    public var now: Date
    public var forcedResults: [SearchResult]?

    public init(
        preferences: Preferences = Preferences(),
        workflows: [Workflow] = [],
        snippets: [Snippet] = [],
        apps: [AppRecord] = [],
        places: [AppRecord] = [],
        settings: [SettingRecord] = [],
        links: [LinkRecord] = [],
        contacts: [ContactRecord] = [],
        clips: [ClipItem] = [],
        files: [AppRecord] = [],
        windows: [WindowInfo] = [],
        processes: [ProcInfo] = [],
        tabs: [LinkRecord] = [],
        profiles: [ProfileInfo] = [],
        definition: String? = nil,
        opItems: [AppRecord] = [],
        knowledge: [String: String] = [:],
        selections: [String: SelectionStat] = [:],
        now: Date = Date(),
        forcedResults: [SearchResult]? = nil
    ) {
        self.preferences = preferences
        self.workflows = workflows
        self.snippets = snippets
        self.apps = apps
        self.places = places
        self.settings = settings
        self.links = links
        self.contacts = contacts
        self.clips = clips
        self.files = files
        self.windows = windows
        self.processes = processes
        self.tabs = tabs
        self.profiles = profiles
        self.definition = definition
        self.opItems = opItems
        self.knowledge = knowledge
        self.selections = selections
        self.now = now
        self.forcedResults = forcedResults
    }
}

public enum UsageMath {
    public static func counts(events: [UsageEvent], days: Int, now: Date = Date()) -> (days: [Date], series: [String: [Int]], total: Int, average: Double, since: Date?) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        var dayStarts: [Date] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            dayStarts.append(calendar.date(byAdding: .day, value: -offset, to: startOfToday) ?? startOfToday)
        }
        var series: [String: [Int]] = [:]
        for category in UsageEvent.categories {
            series[category] = Array(repeating: 0, count: days)
        }
        var total = 0
        var earliest: Date?
        for event in events {
            if earliest == nil || event.date < earliest! { earliest = event.date }
            guard let day = calendar.dateInterval(of: .day, for: event.date)?.start else { continue }
            guard let index = dayStarts.firstIndex(of: day) else { continue }
            total += 1
            var bucket = series[event.category] ?? Array(repeating: 0, count: days)
            if bucket.count != days { bucket = Array(repeating: 0, count: days) }
            bucket[index] += 1
            series[event.category] = bucket
        }
        let span = max(1, days)
        return (dayStarts, series, total, Double(total) / Double(span), earliest)
    }
}

public func expandTokens(_ text: String, now: Date = Date()) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.current
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    let timeFormatter = DateFormatter()
    timeFormatter.locale = Locale.current
    timeFormatter.dateStyle = .none
    timeFormatter.timeStyle = .short
    let iso = ISO8601DateFormatter()
    return text
        .replacingOccurrences(of: "{date}", with: dateFormatter.string(from: now))
        .replacingOccurrences(of: "{time}", with: timeFormatter.string(from: now))
        .replacingOccurrences(of: "{iso}", with: iso.string(from: now))
        .replacingOccurrences(of: "{clipboard}", with: "")
}

public func fillTemplate(_ template: String, query: String) -> String {
    template.replacingOccurrences(of: "{query}", with: query)
}
