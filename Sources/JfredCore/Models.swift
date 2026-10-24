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

public struct CustomTheme: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var width: Double
    public var radius: Double
    public var paddingH: Double
    public var paddingV: Double
    public var querySize: Double
    public var resultTextSize: Double
    public var resultSubtextSize: Double
    public var shortcutSize: Double
    public var iconSize: Double
    public var iconPadding: Double
    public var rowPaddingV: Double
    public var textSpacing: Double
    public var background: String
    public var query: String
    public var title: String
    public var subtitle: String
    public var selected: String
    public var selectedTitle: String
    public var selectedSubtitle: String
    public var searchBackground: String
    public var border: String
    public var fontName: String?

    public init(id: String = UUID().uuidString, name: String, width: Double = 559, radius: Double = 3, paddingH: Double = 9, paddingV: Double = 8, querySize: Double = 34, resultTextSize: Double = 18, resultSubtextSize: Double = 12, shortcutSize: Double = 16, iconSize: Double = 40, iconPadding: Double = 4, rowPaddingV: Double = 3, textSpacing: Double = 5, background: String = "#FFFFFFDB", query: String = "#000000FF", title: String = "#000000E5", subtitle: String = "#00000065", selected: String = "#480069E4", selectedTitle: String = "#FFFFFFFF", selectedSubtitle: String = "#FFFFFFC4", searchBackground: String = "#0000001A", border: String = "#0000007F", fontName: String? = nil) {
        self.id = id
        self.name = name
        self.width = width
        self.radius = radius
        self.paddingH = paddingH
        self.paddingV = paddingV
        self.querySize = querySize
        self.resultTextSize = resultTextSize
        self.resultSubtextSize = resultSubtextSize
        self.shortcutSize = shortcutSize
        self.iconSize = iconSize
        self.iconPadding = iconPadding
        self.rowPaddingV = rowPaddingV
        self.textSpacing = textSpacing
        self.background = background
        self.query = query
        self.title = title
        self.subtitle = subtitle
        self.selected = selected
        self.selectedTitle = selectedTitle
        self.selectedSubtitle = selectedSubtitle
        self.searchBackground = searchBackground
        self.border = border
        self.fontName = fontName
    }
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
    public var urlHistory: [String]
    public var themeID: String
    public var customThemes: [CustomTheme]
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

    // File search keywords, filters and result limit.
    public var quickSearchEnabled: Bool
    public var fileOpenKeyword: String
    public var fileFindKeyword: String
    public var fileInsideKeyword: String
    public var fileTagsKeyword: String
    public var hiddenFileTypes: [String]
    public var fileOpenEnabled: Bool
    public var fileFindEnabled: Bool
    public var fileInsideEnabled: Bool
    public var fileTagsEnabled: Bool

    // Bookmark result behaviour.
    public var bookmarkResultMode: String
    public var bookmarkOpenMode: String
    public var bookmarkKeyword: String
    public var fileOpenWithFinder: Bool
    public var clipboardIgnoreDuplicates: Bool
    public var clipboardClearOnQuit: Bool
    public var clipboardIgnoreUniversalText: Bool
    public var clipboardIgnoreUniversalFiles: Bool

    // Clipboard history.
    public var clipboardKeepText: Bool
    public var clipboardKeepImages: Bool
    public var clipboardKeepFiles: Bool
    public var clipboardRetention: String
    public var clipboardViewerKeyword: String
    public var clipboardClearKeyword: String
    public var clipboardClearKeywordEnabled: Bool

    // Snippets.
    public var snippetKeyword: String
    public var snippetShowKeywordInResult: Bool
    public var snippetMatching: String
    public var snippetWordBased: Bool
    public var snippetExpandPlaySound: Bool
    public var snippetExpandRestoreClipboard: Bool

    // Large type.
    public var largeTypeBackgroundMode: String
    public var largeTypeAutoHide: Bool
    public var largeTypeShowOnMouseScreen: Bool

    // Previews.
    public var richPreviewsEnabled: Bool
    public var noPreviewTypes: [String]
    public var noPreviewPaths: [String]

    // Contacts.
    public var contactsEnabled: Bool
    public var contactsOpenInAlfred: Bool
    public var contactsShowTitle: Bool
    public var contactsShowJobTitle: Bool
    public var contactsShowNotes: Bool
    public var contactsInvertName: Bool
    public var contactsMapURL: String
    public var contactsURLHandler: String
    public var contactsURLHandlerEnabled: Bool

    // Music.
    public var musicEnabled: Bool
    public var musicKeyword: String
    public var musicHideMiniPlayerAfterSong: Bool
    public var musicRandomLargerAlbums: Bool
    public var musicIncludePlaylists: Bool

    // Clipboard additions.
    public var clipboardAutoPaste: Bool
    public var clipboardFastAppend: Bool
    public var clipboardFastAppendSeparator: String
    public var clipboardFastAppendBackToClipboard: Bool
    public var clipboardFastAppendPlaySound: Bool
    public var clipboardMaxSize: Int
    public var clipboardIgnoreConcealed: Bool
    public var clipboardIgnoreAutoGenerated: Bool
    public var clipboardUnicodeMatching: Bool
    public var clipboardMoveToTopOnUse: Bool
    public var clipboardSnippetsAtTop: Bool
    public var clipboardSnippetsWhenSearching: Bool
    public var clipboardConvertImagesToPNG: Bool
    public var clipboardIgnoreApps: [String]

    // File search additions.
    public var fileNavigateWithArrows: Bool
    public var fileOpenFoldersInFinder: Bool
    public var fileUseShiftOptionBuffer: Bool
    public var fileClearBufferAfterAction: Bool
    public var fileBufferTimeoutMinutes: Int
    public var fileCustomHomeFolder: String
    public var fileEscapePathForTerminal: Bool
    public var fileRunAppleScriptsInsteadOfOpening: Bool
    public var fileUseTypeIconsForExternal: Bool
    public var fileTouchFolders: Bool
    public var fileTouchAliases: Bool

    // Calculator additions.
    public var calculatorAdvanced: Bool
    public var calculatorInputType: String
    public var calculatorOutputType: String
    public var calculatorInputThousands: Bool
    public var calculatorOutputThousands: Bool

    // Dictionary.
    public var dictionaryDefineEnabled: Bool
    public var dictionarySpellEnabled: Bool
    public var dictionaryDefineKeyword: String
    public var dictionarySpellKeyword: String
    public var dictionaryLanguage: String
    public var dictionaryPasteOnAction: Bool
    public var dictionaryOnlyDictionary: Bool

    // Terminal.
    public var terminalPrefix: String
    public var terminalCustomScript: String

    // Universal Actions.
    public var uaShowRightArrow: Bool
    public var uaShowFunction: Bool
    public var uaShowControl: Bool
    public var uaShowCommand: Bool
    public var uaSelectionHotkey: String
    public var uaSortByUsage: Bool

    // System commands.
    public var systemKeywords: [String: String]
    public var systemConfirm: [String]
    public var systemDisabled: [String]
    public var ejectScope: String
    public var ejectAllEnabled: Bool
    public var ejectExclusions: [String]

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
        urlHistory = []
        themeID = "alfred"
        customThemes = []
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
        quickSearchEnabled = true
        fileOpenKeyword = "open"
        fileFindKeyword = "find"
        fileInsideKeyword = "in"
        fileTagsKeyword = "tags"
        hiddenFileTypes = []
        fileOpenEnabled = true
        fileFindEnabled = true
        fileInsideEnabled = true
        fileTagsEnabled = true
        bookmarkResultMode = "default"
        bookmarkOpenMode = "macos"
        bookmarkKeyword = "bm"
        fileOpenWithFinder = false
        clipboardIgnoreDuplicates = true
        clipboardClearOnQuit = false
        clipboardIgnoreUniversalText = false
        clipboardIgnoreUniversalFiles = false
        clipboardKeepText = true
        clipboardKeepImages = true
        clipboardKeepFiles = true
        clipboardRetention = "3 months"
        clipboardViewerKeyword = "clipboard"
        clipboardClearKeyword = "clear"
        clipboardClearKeywordEnabled = true
        snippetKeyword = "snip"
        snippetShowKeywordInResult = true
        snippetMatching = "nameandkeyword"
        snippetWordBased = true
        snippetExpandPlaySound = true
        snippetExpandRestoreClipboard = true
        largeTypeBackgroundMode = "fit"
        largeTypeAutoHide = true
        largeTypeShowOnMouseScreen = false
        richPreviewsEnabled = true
        noPreviewTypes = []
        noPreviewPaths = []
        contactsEnabled = true
        contactsOpenInAlfred = false
        contactsShowTitle = false
        contactsShowJobTitle = false
        contactsShowNotes = true
        contactsInvertName = false
        contactsMapURL = "https://maps.apple.com/?q={query}"
        contactsURLHandler = "addressbook://{uid}"
        contactsURLHandlerEnabled = false
        musicEnabled = true
        musicKeyword = "music"
        musicHideMiniPlayerAfterSong = true
        musicRandomLargerAlbums = true
        musicIncludePlaylists = true
        clipboardAutoPaste = true
        clipboardFastAppend = false
        clipboardFastAppendSeparator = "space"
        clipboardFastAppendBackToClipboard = false
        clipboardFastAppendPlaySound = true
        clipboardMaxSize = 262144
        clipboardIgnoreConcealed = true
        clipboardIgnoreAutoGenerated = true
        clipboardUnicodeMatching = false
        clipboardMoveToTopOnUse = true
        clipboardSnippetsAtTop = true
        clipboardSnippetsWhenSearching = true
        clipboardConvertImagesToPNG = false
        clipboardIgnoreApps = ["1Password", "Keychain Access", "Passwords", "Wallet", "SecurityAgent"]
        fileNavigateWithArrows = false
        fileOpenFoldersInFinder = false
        fileUseShiftOptionBuffer = false
        fileClearBufferAfterAction = false
        fileBufferTimeoutMinutes = 5
        fileCustomHomeFolder = "~"
        fileEscapePathForTerminal = false
        fileRunAppleScriptsInsteadOfOpening = false
        fileUseTypeIconsForExternal = false
        fileTouchFolders = false
        fileTouchAliases = false
        calculatorAdvanced = true
        calculatorInputType = "standard"
        calculatorOutputType = "standard"
        calculatorInputThousands = false
        calculatorOutputThousands = true
        dictionaryDefineEnabled = true
        dictionarySpellEnabled = true
        dictionaryDefineKeyword = "define"
        dictionarySpellKeyword = "spell"
        dictionaryLanguage = "Default"
        dictionaryPasteOnAction = false
        dictionaryOnlyDictionary = true
        terminalPrefix = ">"
        terminalCustomScript = ""
        uaShowRightArrow = true
        uaShowFunction = true
        uaShowControl = false
        uaShowCommand = false
        uaSelectionHotkey = "⌥⌘\\"
        uaSortByUsage = false
        systemKeywords = [:]
        systemConfirm = []
        systemDisabled = []
        ejectScope = "local"
        ejectAllEnabled = false
        ejectExclusions = []
    }

    private enum CodingKeys: String, CodingKey {
        case launchAtLogin, hotkey, location, useDotCom, systemSettingsEnabled
        case extraFolders, extraDocuments, extraText, extraImages, extraArchives, extraScripts
        case searchAllFileTypes, scopeApplications, scopeHome, scopePaths
        case includeSystemApps, includeUserApps, includePreferencePanes
        case fallbackMode, webSearches, urlHistory, themeID, customThemes
        case storeTypedQuery, showLatestQuery, topResultLatching
        case removeNotificationWhenClicked, showNotificationIcons, useHTTPProxy
        case selectionHotkeyMode, forceKeyboard, modifierControl, modifierOption, modifierCommand
        case syncFolder, snippetsEnabled, clipboardEnabled, clipboardLimit
        case calculatorEnabled, dictionaryEnabled, onePasswordEnabled
        case largeTypeSize, largeTypeFont, quickLookEnabled, terminalApp, fileSearchMax
        case remoteEnabled, remoteLocalOnly, remoteToken, remotePort, autoUpdateCheck
        case recentQueries, lastQueryDate, newsletterEmail, safariBookmarks, chromeBookmarks
        case fileBufferEnabled
        case quickSearchEnabled, fileOpenKeyword, fileFindKeyword, fileInsideKeyword
        case fileTagsKeyword, hiddenFileTypes, fileOpenEnabled, fileFindEnabled
        case fileInsideEnabled, fileTagsEnabled, bookmarkResultMode, bookmarkOpenMode, bookmarkKeyword
        case fileOpenWithFinder, clipboardIgnoreDuplicates, clipboardClearOnQuit
        case clipboardIgnoreUniversalText, clipboardIgnoreUniversalFiles
        case clipboardKeepText, clipboardKeepImages, clipboardKeepFiles, clipboardRetention
        case clipboardViewerKeyword, clipboardClearKeyword, clipboardClearKeywordEnabled
        case snippetKeyword, snippetShowKeywordInResult, snippetMatching, snippetWordBased
        case snippetExpandPlaySound, snippetExpandRestoreClipboard
        case largeTypeBackgroundMode, largeTypeAutoHide, largeTypeShowOnMouseScreen
        case richPreviewsEnabled, noPreviewTypes, noPreviewPaths
        case systemKeywords, systemConfirm, systemDisabled, ejectScope, ejectAllEnabled, ejectExclusions
        case dictionaryDefineEnabled, dictionarySpellEnabled, dictionaryDefineKeyword, dictionarySpellKeyword
        case dictionaryLanguage, dictionaryPasteOnAction, dictionaryOnlyDictionary
        case terminalPrefix, terminalCustomScript
        case uaShowRightArrow, uaShowFunction, uaShowControl, uaShowCommand, uaSelectionHotkey, uaSortByUsage
        case contactsEnabled, contactsOpenInAlfred, contactsShowTitle, contactsShowJobTitle
        case contactsShowNotes, contactsInvertName, contactsMapURL, contactsURLHandler, contactsURLHandlerEnabled
        case musicEnabled, musicKeyword, musicHideMiniPlayerAfterSong, musicRandomLargerAlbums, musicIncludePlaylists
        case clipboardAutoPaste, clipboardFastAppend, clipboardFastAppendSeparator
        case clipboardFastAppendBackToClipboard, clipboardFastAppendPlaySound, clipboardMaxSize
        case clipboardIgnoreConcealed, clipboardIgnoreAutoGenerated, clipboardUnicodeMatching
        case clipboardMoveToTopOnUse, clipboardSnippetsAtTop, clipboardSnippetsWhenSearching, clipboardConvertImagesToPNG
        case clipboardIgnoreApps
        case fileNavigateWithArrows, fileOpenFoldersInFinder, fileUseShiftOptionBuffer
        case fileClearBufferAfterAction, fileBufferTimeoutMinutes, fileCustomHomeFolder
        case fileEscapePathForTerminal, fileRunAppleScriptsInsteadOfOpening
        case fileUseTypeIconsForExternal, fileTouchFolders, fileTouchAliases
        case calculatorAdvanced, calculatorInputType, calculatorOutputType
        case calculatorInputThousands, calculatorOutputThousands
    }

    /// Decodes older saved state: every key is optional and falls back to the
    /// current default, so adding a preference never wipes existing settings.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Preferences()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decode(T.self, forKey: key)) ?? fallback
        }
        launchAtLogin = value(.launchAtLogin, d.launchAtLogin)
        hotkey = value(.hotkey, d.hotkey)
        location = value(.location, d.location)
        useDotCom = value(.useDotCom, d.useDotCom)
        systemSettingsEnabled = value(.systemSettingsEnabled, d.systemSettingsEnabled)
        extraFolders = value(.extraFolders, d.extraFolders)
        extraDocuments = value(.extraDocuments, d.extraDocuments)
        extraText = value(.extraText, d.extraText)
        extraImages = value(.extraImages, d.extraImages)
        extraArchives = value(.extraArchives, d.extraArchives)
        extraScripts = value(.extraScripts, d.extraScripts)
        searchAllFileTypes = value(.searchAllFileTypes, d.searchAllFileTypes)
        scopeApplications = value(.scopeApplications, d.scopeApplications)
        scopeHome = value(.scopeHome, d.scopeHome)
        scopePaths = value(.scopePaths, d.scopePaths)
        includeSystemApps = value(.includeSystemApps, d.includeSystemApps)
        includeUserApps = value(.includeUserApps, d.includeUserApps)
        includePreferencePanes = value(.includePreferencePanes, d.includePreferencePanes)
        fallbackMode = value(.fallbackMode, d.fallbackMode)
        webSearches = value(.webSearches, d.webSearches)
        urlHistory = value(.urlHistory, d.urlHistory)
        themeID = value(.themeID, d.themeID)
        customThemes = value(.customThemes, d.customThemes)
        storeTypedQuery = value(.storeTypedQuery, d.storeTypedQuery)
        showLatestQuery = value(.showLatestQuery, d.showLatestQuery)
        topResultLatching = value(.topResultLatching, d.topResultLatching)
        removeNotificationWhenClicked = value(.removeNotificationWhenClicked, d.removeNotificationWhenClicked)
        showNotificationIcons = value(.showNotificationIcons, d.showNotificationIcons)
        useHTTPProxy = value(.useHTTPProxy, d.useHTTPProxy)
        selectionHotkeyMode = value(.selectionHotkeyMode, d.selectionHotkeyMode)
        forceKeyboard = value(.forceKeyboard, d.forceKeyboard)
        modifierControl = value(.modifierControl, d.modifierControl)
        modifierOption = value(.modifierOption, d.modifierOption)
        modifierCommand = value(.modifierCommand, d.modifierCommand)
        syncFolder = value(.syncFolder, d.syncFolder)
        snippetsEnabled = value(.snippetsEnabled, d.snippetsEnabled)
        clipboardEnabled = value(.clipboardEnabled, d.clipboardEnabled)
        clipboardLimit = value(.clipboardLimit, d.clipboardLimit)
        calculatorEnabled = value(.calculatorEnabled, d.calculatorEnabled)
        dictionaryEnabled = value(.dictionaryEnabled, d.dictionaryEnabled)
        onePasswordEnabled = value(.onePasswordEnabled, d.onePasswordEnabled)
        largeTypeSize = value(.largeTypeSize, d.largeTypeSize)
        largeTypeFont = value(.largeTypeFont, d.largeTypeFont)
        quickLookEnabled = value(.quickLookEnabled, d.quickLookEnabled)
        terminalApp = value(.terminalApp, d.terminalApp)
        fileSearchMax = value(.fileSearchMax, d.fileSearchMax)
        remoteEnabled = value(.remoteEnabled, d.remoteEnabled)
        remoteLocalOnly = value(.remoteLocalOnly, d.remoteLocalOnly)
        remoteToken = value(.remoteToken, d.remoteToken)
        remotePort = value(.remotePort, d.remotePort)
        autoUpdateCheck = value(.autoUpdateCheck, d.autoUpdateCheck)
        recentQueries = value(.recentQueries, d.recentQueries)
        lastQueryDate = value(.lastQueryDate, d.lastQueryDate)
        newsletterEmail = value(.newsletterEmail, d.newsletterEmail)
        safariBookmarks = value(.safariBookmarks, d.safariBookmarks)
        chromeBookmarks = value(.chromeBookmarks, d.chromeBookmarks)
        fileBufferEnabled = value(.fileBufferEnabled, d.fileBufferEnabled)
        quickSearchEnabled = value(.quickSearchEnabled, d.quickSearchEnabled)
        fileOpenKeyword = value(.fileOpenKeyword, d.fileOpenKeyword)
        fileFindKeyword = value(.fileFindKeyword, d.fileFindKeyword)
        fileInsideKeyword = value(.fileInsideKeyword, d.fileInsideKeyword)
        fileTagsKeyword = value(.fileTagsKeyword, d.fileTagsKeyword)
        hiddenFileTypes = value(.hiddenFileTypes, d.hiddenFileTypes)
        fileOpenEnabled = value(.fileOpenEnabled, d.fileOpenEnabled)
        fileFindEnabled = value(.fileFindEnabled, d.fileFindEnabled)
        fileInsideEnabled = value(.fileInsideEnabled, d.fileInsideEnabled)
        fileTagsEnabled = value(.fileTagsEnabled, d.fileTagsEnabled)
        bookmarkResultMode = value(.bookmarkResultMode, d.bookmarkResultMode)
        bookmarkOpenMode = value(.bookmarkOpenMode, d.bookmarkOpenMode)
        bookmarkKeyword = value(.bookmarkKeyword, d.bookmarkKeyword)
        fileOpenWithFinder = value(.fileOpenWithFinder, d.fileOpenWithFinder)
        clipboardIgnoreDuplicates = value(.clipboardIgnoreDuplicates, d.clipboardIgnoreDuplicates)
        clipboardClearOnQuit = value(.clipboardClearOnQuit, d.clipboardClearOnQuit)
        clipboardIgnoreUniversalText = value(.clipboardIgnoreUniversalText, d.clipboardIgnoreUniversalText)
        clipboardIgnoreUniversalFiles = value(.clipboardIgnoreUniversalFiles, d.clipboardIgnoreUniversalFiles)
        clipboardKeepText = value(.clipboardKeepText, d.clipboardKeepText)
        clipboardKeepImages = value(.clipboardKeepImages, d.clipboardKeepImages)
        clipboardKeepFiles = value(.clipboardKeepFiles, d.clipboardKeepFiles)
        clipboardRetention = value(.clipboardRetention, d.clipboardRetention)
        clipboardViewerKeyword = value(.clipboardViewerKeyword, d.clipboardViewerKeyword)
        clipboardClearKeyword = value(.clipboardClearKeyword, d.clipboardClearKeyword)
        clipboardClearKeywordEnabled = value(.clipboardClearKeywordEnabled, d.clipboardClearKeywordEnabled)
        snippetKeyword = value(.snippetKeyword, d.snippetKeyword)
        snippetShowKeywordInResult = value(.snippetShowKeywordInResult, d.snippetShowKeywordInResult)
        snippetMatching = value(.snippetMatching, d.snippetMatching)
        snippetWordBased = value(.snippetWordBased, d.snippetWordBased)
        snippetExpandPlaySound = value(.snippetExpandPlaySound, d.snippetExpandPlaySound)
        snippetExpandRestoreClipboard = value(.snippetExpandRestoreClipboard, d.snippetExpandRestoreClipboard)
        largeTypeBackgroundMode = value(.largeTypeBackgroundMode, d.largeTypeBackgroundMode)
        largeTypeAutoHide = value(.largeTypeAutoHide, d.largeTypeAutoHide)
        largeTypeShowOnMouseScreen = value(.largeTypeShowOnMouseScreen, d.largeTypeShowOnMouseScreen)
        richPreviewsEnabled = value(.richPreviewsEnabled, d.richPreviewsEnabled)
        noPreviewTypes = value(.noPreviewTypes, d.noPreviewTypes)
        noPreviewPaths = value(.noPreviewPaths, d.noPreviewPaths)
        contactsEnabled = value(.contactsEnabled, d.contactsEnabled)
        contactsOpenInAlfred = value(.contactsOpenInAlfred, d.contactsOpenInAlfred)
        contactsShowTitle = value(.contactsShowTitle, d.contactsShowTitle)
        contactsShowJobTitle = value(.contactsShowJobTitle, d.contactsShowJobTitle)
        contactsShowNotes = value(.contactsShowNotes, d.contactsShowNotes)
        contactsInvertName = value(.contactsInvertName, d.contactsInvertName)
        contactsMapURL = value(.contactsMapURL, d.contactsMapURL)
        contactsURLHandler = value(.contactsURLHandler, d.contactsURLHandler)
        contactsURLHandlerEnabled = value(.contactsURLHandlerEnabled, d.contactsURLHandlerEnabled)
        musicEnabled = value(.musicEnabled, d.musicEnabled)
        musicKeyword = value(.musicKeyword, d.musicKeyword)
        musicHideMiniPlayerAfterSong = value(.musicHideMiniPlayerAfterSong, d.musicHideMiniPlayerAfterSong)
        musicRandomLargerAlbums = value(.musicRandomLargerAlbums, d.musicRandomLargerAlbums)
        musicIncludePlaylists = value(.musicIncludePlaylists, d.musicIncludePlaylists)
        clipboardAutoPaste = value(.clipboardAutoPaste, d.clipboardAutoPaste)
        clipboardFastAppend = value(.clipboardFastAppend, d.clipboardFastAppend)
        clipboardFastAppendSeparator = value(.clipboardFastAppendSeparator, d.clipboardFastAppendSeparator)
        clipboardFastAppendBackToClipboard = value(.clipboardFastAppendBackToClipboard, d.clipboardFastAppendBackToClipboard)
        clipboardFastAppendPlaySound = value(.clipboardFastAppendPlaySound, d.clipboardFastAppendPlaySound)
        clipboardMaxSize = value(.clipboardMaxSize, d.clipboardMaxSize)
        clipboardIgnoreConcealed = value(.clipboardIgnoreConcealed, d.clipboardIgnoreConcealed)
        clipboardIgnoreAutoGenerated = value(.clipboardIgnoreAutoGenerated, d.clipboardIgnoreAutoGenerated)
        clipboardUnicodeMatching = value(.clipboardUnicodeMatching, d.clipboardUnicodeMatching)
        clipboardMoveToTopOnUse = value(.clipboardMoveToTopOnUse, d.clipboardMoveToTopOnUse)
        clipboardSnippetsAtTop = value(.clipboardSnippetsAtTop, d.clipboardSnippetsAtTop)
        clipboardSnippetsWhenSearching = value(.clipboardSnippetsWhenSearching, d.clipboardSnippetsWhenSearching)
        clipboardConvertImagesToPNG = value(.clipboardConvertImagesToPNG, d.clipboardConvertImagesToPNG)
        clipboardIgnoreApps = value(.clipboardIgnoreApps, d.clipboardIgnoreApps)
        fileNavigateWithArrows = value(.fileNavigateWithArrows, d.fileNavigateWithArrows)
        fileOpenFoldersInFinder = value(.fileOpenFoldersInFinder, d.fileOpenFoldersInFinder)
        fileUseShiftOptionBuffer = value(.fileUseShiftOptionBuffer, d.fileUseShiftOptionBuffer)
        fileClearBufferAfterAction = value(.fileClearBufferAfterAction, d.fileClearBufferAfterAction)
        fileBufferTimeoutMinutes = value(.fileBufferTimeoutMinutes, d.fileBufferTimeoutMinutes)
        fileCustomHomeFolder = value(.fileCustomHomeFolder, d.fileCustomHomeFolder)
        fileEscapePathForTerminal = value(.fileEscapePathForTerminal, d.fileEscapePathForTerminal)
        fileRunAppleScriptsInsteadOfOpening = value(.fileRunAppleScriptsInsteadOfOpening, d.fileRunAppleScriptsInsteadOfOpening)
        fileUseTypeIconsForExternal = value(.fileUseTypeIconsForExternal, d.fileUseTypeIconsForExternal)
        fileTouchFolders = value(.fileTouchFolders, d.fileTouchFolders)
        fileTouchAliases = value(.fileTouchAliases, d.fileTouchAliases)
        calculatorAdvanced = value(.calculatorAdvanced, d.calculatorAdvanced)
        calculatorInputType = value(.calculatorInputType, d.calculatorInputType)
        calculatorOutputType = value(.calculatorOutputType, d.calculatorOutputType)
        calculatorInputThousands = value(.calculatorInputThousands, d.calculatorInputThousands)
        calculatorOutputThousands = value(.calculatorOutputThousands, d.calculatorOutputThousands)
        dictionaryDefineEnabled = value(.dictionaryDefineEnabled, d.dictionaryDefineEnabled)
        dictionarySpellEnabled = value(.dictionarySpellEnabled, d.dictionarySpellEnabled)
        dictionaryDefineKeyword = value(.dictionaryDefineKeyword, d.dictionaryDefineKeyword)
        dictionarySpellKeyword = value(.dictionarySpellKeyword, d.dictionarySpellKeyword)
        dictionaryLanguage = value(.dictionaryLanguage, d.dictionaryLanguage)
        dictionaryPasteOnAction = value(.dictionaryPasteOnAction, d.dictionaryPasteOnAction)
        dictionaryOnlyDictionary = value(.dictionaryOnlyDictionary, d.dictionaryOnlyDictionary)
        terminalPrefix = value(.terminalPrefix, d.terminalPrefix)
        terminalCustomScript = value(.terminalCustomScript, d.terminalCustomScript)
        uaShowRightArrow = value(.uaShowRightArrow, d.uaShowRightArrow)
        uaShowFunction = value(.uaShowFunction, d.uaShowFunction)
        uaShowControl = value(.uaShowControl, d.uaShowControl)
        uaShowCommand = value(.uaShowCommand, d.uaShowCommand)
        uaSelectionHotkey = value(.uaSelectionHotkey, d.uaSelectionHotkey)
        uaSortByUsage = value(.uaSortByUsage, d.uaSortByUsage)
        systemKeywords = value(.systemKeywords, d.systemKeywords)
        systemConfirm = value(.systemConfirm, d.systemConfirm)
        systemDisabled = value(.systemDisabled, d.systemDisabled)
        ejectScope = value(.ejectScope, d.ejectScope)
        ejectAllEnabled = value(.ejectAllEnabled, d.ejectAllEnabled)
        ejectExclusions = value(.ejectExclusions, d.ejectExclusions)
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
    public var collection: String

    public init(id: UUID = UUID(), name: String, keyword: String, text: String, autoExpand: Bool = true, collection: String = "") {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.text = text
        self.autoExpand = autoExpand
        self.collection = collection
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, keyword, text, autoExpand, collection
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        keyword = try container.decode(String.self, forKey: .keyword)
        text = try container.decode(String.self, forKey: .text)
        autoExpand = try container.decodeIfPresent(Bool.self, forKey: .autoExpand) ?? true
        collection = try container.decodeIfPresent(String.self, forKey: .collection) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(keyword, forKey: .keyword)
        try container.encode(text, forKey: .text)
        try container.encode(autoExpand, forKey: .autoExpand)
        try container.encode(collection, forKey: .collection)
    }
}

public struct ClipItem: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var text: String
    public var date: Date
    /// "text", "image" or "file"; older saved clips have nil and are treated as text.
    public var kind: String?
    public var imageFile: String?
    public var filePaths: [String]?

    public init(id: UUID = UUID(), text: String, date: Date, kind: String? = nil, imageFile: String? = nil, filePaths: [String]? = nil) {
        self.id = id
        self.text = text
        self.date = date
        self.kind = kind
        self.imageFile = imageFile
        self.filePaths = filePaths
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
    public var uid: String?
    public var jobTitle: String?
    public var notes: String?
    public var organization: String?

    public init(id: String, name: String, email: String, phone: String, uid: String? = nil, jobTitle: String? = nil, notes: String? = nil, organization: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.uid = uid
        self.jobTitle = jobTitle
        self.notes = notes
        self.organization = organization
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
    /// Spotlight-backed lookup for file contents (tags == false) or file tags (tags == true).
    public var spotlight: (@Sendable (String, Bool) -> [AppRecord])?

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
        forcedResults: [SearchResult]? = nil,
        spotlight: (@Sendable (String, Bool) -> [AppRecord])? = nil
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
        self.spotlight = spotlight
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
