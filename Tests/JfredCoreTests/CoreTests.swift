import Foundation
import Testing
@testable import JfredCore

struct CoreTests {
    @Test func calculatorPrecedence() {
        #expect(Calculator.evaluate("2+2*3") == 8)
        #expect(Calculator.evaluate("(2+2)*3") == 12)
        #expect(Calculator.evaluate("sqrt(9)") == 3)
        #expect(Calculator.evaluate("=10/4") == 2.5)
        #expect(Calculator.evaluate("contacts") == nil)
    }

    @Test func units() {
        let length = Units.convert("10 km in m")
        #expect(length?.value == 10000)
        #expect(length?.text == "10000 m")
        let temp = Units.convert("32 f in c")
        #expect(abs((temp?.value ?? -1) - 0) < 0.001)
        #expect(Units.convert("10 km in kg") == nil)
    }

    @Test func searchPrefixesAndFallbacks() {
        var context = SearchContext()
        context.apps = [
            AppRecord(id: "contacts", name: "Contacts", path: "/Applications/Contacts.app"),
            AppRecord(id: "console", name: "Console", path: "/Applications/Utilities/Console.app"),
            AppRecord(id: "color", name: "ColorSync Utility", path: "/Applications/Utilities/ColorSync Utility.app"),
        ]
        context.places = [
            AppRecord(id: "computer", name: "Computer", path: ""),
        ]
        let co = Search.results(for: "co", context: context).map(\.title)
        #expect(co.contains("Computer"))
        #expect(co.contains("Console"))
        #expect(co.contains("Contacts"))
        #expect(co.firstIndex(of: "Contacts")! < co.firstIndex(of: "Computer")!)
        #expect(co.firstIndex(of: "Console")! < co.firstIndex(of: "Computer")!)

        let missing = Search.results(for: "zzzz-no-such", context: context)
        #expect(missing.contains { $0.title.contains("Google") })
        #expect(Search.results(for: "", context: context).isEmpty)
        #expect(Search.results(for: " ", context: context).first?.kind == "text")
        #expect(Search.results(for: "2+2*3", context: context).first?.title == "8")
    }

    @Test func settingsFollowAppsThatContainTheQuery() {
        var context = SearchContext()
        context.apps = [
            AppRecord(id: "displaycal", name: "DisplayCal", path: "/Applications/DisplayCal.app"),
            AppRecord(id: "notes", name: "Notes", path: "/Applications/Notes.app"),
        ]
        context.settings = SettingsCatalog.all
        let rows = Search.results(for: "disp", context: context)
        let app = rows.firstIndex { $0.title == "DisplayCal" }
        let displays = rows.firstIndex { $0.id == "set:displays" }
        let notes = rows.firstIndex { $0.title == "Notes" }
        #expect(app != nil)
        #expect(displays != nil)
        #expect(app! < displays!)
        #expect(rows.filter { $0.kind == "settings" }.allSatisfy { fold($0.title).contains("disp") })
        if let notes, let displays {
            #expect(displays < notes)
        }
    }

    @Test func matchTierOutranksUsageAndShorterNames() {
        #expect(fieldMatch(query: "cal", target: "Calendar")?.tier == 1)
        #expect(fieldMatch(query: "cal", target: "Local")?.tier == 3) // contiguous substring, not fuzzy
        var context = SearchContext()
        context.apps = [
            AppRecord(id: "local", name: "Local", path: "/Applications/Local.app"),
            AppRecord(id: "calendar", name: "Calendar", path: "/System/Applications/Calendar.app"),
            AppRecord(id: "alpha", name: "Alpha", path: "/Applications/Alpha.app"),
            AppRecord(id: "alpine", name: "Alpine", path: "/Applications/Alpine.app"),
        ]
        context.selections["app:/Applications/Local.app"] = SelectionStat(count: 40, lastSelected: Date())
        let cal = Search.results(for: "cal", context: context)
        #expect(cal.first?.title == "Calendar")
        context.selections["app:/Applications/Alpine.app"] = SelectionStat(count: 5, lastSelected: Date())
        let rows = Search.results(for: "al", context: context)
        let alpine = rows.firstIndex { $0.title == "Alpine" }
        let alpha = rows.firstIndex { $0.title == "Alpha" }
        #expect(alpine != nil)
        #expect(alpha != nil)
        #expect(alpine! < alpha!)
    }

    @Test func shortQueryKeepsWordPrefixesOnly() {
        var context = SearchContext()
        context.apps = [
            AppRecord(id: "enhanced", name: "Enhanced Logging", path: "/System/Library/CoreServices/Enhanced Logging.app"),
            AppRecord(id: "handler", name: "CalendarFileHandler", path: "/System/Library/CoreServices/CalendarFileHandler.app"),
            AppRecord(id: "host", name: "Hostpane", path: "/Applications/Hostpane.app"),
            AppRecord(id: "hagi", name: "HagimiMonitor", path: "/Applications/HagimiMonitor.app"),
            AppRecord(id: "claude", name: "Claude Code URL Handler", path: "/Users/jim/Applications/Claude Code URL Handler.app"),
        ]
        context.settings = [SettingRecord(id: "sharing", name: "Sharing", url: "x-apple.systempreferences:com.apple.Sharing-Settings.extension")]
        let rows = Search.results(for: "ha", context: context)
        #expect(rows.map(\.title) == ["HagimiMonitor", "Claude Code URL Handler"])
    }

    @Test func applicationsFolderRanksBeforeOtherApps() {
        var context = SearchContext()
        context.apps = [
            AppRecord(id: "apps", name: "Apps", path: "/System/Applications/Apps.app"),
            AppRecord(id: "alfred", name: "Alfred 5", path: "/Applications/Alfred 5.app"),
            AppRecord(id: "accounts", name: "Accounts", path: "/System/Library/PreferencePanes/Accounts.prefPane"),
        ]
        let rows = Search.results(for: "a", context: context)
        let alfred = rows.firstIndex { $0.title == "Alfred 5" }
        let apps = rows.firstIndex { $0.title == "Apps" }
        let accounts = rows.firstIndex { $0.title == "Accounts" }
        #expect(alfred != nil)
        #expect(apps != nil)
        #expect(accounts != nil)
        #expect(alfred! < apps!)
        #expect(alfred! < accounts!)
    }

    @Test func appsRankBeforeOtherMatches() {
        var context = SearchContext()
        context.apps = [
            AppRecord(id: "safari", name: "Safari", path: "/Applications/Safari.app"),
        ]
        let rows = Search.results(for: "s", context: context)
        let safari = rows.firstIndex { $0.title == "Safari" }
        let sleep = rows.firstIndex { $0.title == "Sleep" }
        #expect(rows.first?.kind == "app")
        #expect(safari != nil)
        #expect(sleep != nil)
        #expect(safari! < sleep!)
    }

    @Test func coreServicesHelpersStayOut() {
        var context = SearchContext()
        context.apps = [
            AppRecord(id: "enhanced", name: "Enhanced Logging", path: "/System/Library/CoreServices/Enhanced Logging.app"),
            AppRecord(id: "finder", name: "Finder", path: "/System/Library/CoreServices/Finder.app"),
            AppRecord(id: "keychain", name: "Keychain Access", path: "/System/Library/CoreServices/Applications/Keychain Access.app"),
        ]
        let rows = Search.results(for: "f", context: context)
        #expect(rows.contains { $0.title == "Finder" })
        #expect(!Search.results(for: "en", context: context).contains { $0.title == "Enhanced Logging" })
        let key = Search.results(for: "key", context: context)
        #expect(key.contains { $0.title == "Keychain Access" })
    }

    @Test func fileModeDoesNotReturnApps() {
        var context = SearchContext()
        context.apps = [AppRecord(id: "r", name: "Report", path: "/Applications/Report.app")]
        context.files = [AppRecord(id: "f", name: "Report.pdf", path: "/Users/me/Report.pdf")]
        let rows = Search.results(for: " report", context: context)
        #expect(rows.map(\.kind) == ["file"])
        #expect(Search.wantsFiles(raw: " report", preferences: context.preferences))
    }

    @Test func webKeyword() {
        let context = SearchContext()
        let rows = Search.results(for: "g jfred", context: context)
        #expect(rows.count == 1)
        #expect(rows[0].kind == "url")
        #expect(rows[0].payload.contains("google.com"))
    }

    @Test func usageBuckets() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let events = [
            UsageEvent(date: now, category: "general"),
            UsageEvent(date: now, category: "hotkeys"),
        ]
        let stats = UsageMath.counts(events: events, days: 28, now: now)
        #expect(stats.total == 2)
        #expect(stats.series["general"]?.reduce(0, +) == 1)
        #expect(stats.series["hotkeys"]?.reduce(0, +) == 1)
    }
}

    @Test func contactsAndMusicResults() {
        var context = SearchContext()
        context.preferences.contactsEnabled = true
        context.contacts = [
            ContactRecord(id: "ada", name: "Ada Lovelace", email: "ada@example.com", phone: "", uid: "ada"),
        ]
        let people = Search.results(for: "lovelace", context: context)
        #expect(people.contains { $0.kind == "contact" && $0.title == "Ada Lovelace" })

        context.preferences.contactsEnabled = false
        #expect(!Search.results(for: "lovelace", context: context).contains { $0.kind == "contact" })

        context.preferences.musicEnabled = true
        let playback = Search.results(for: "play daft punk", context: context)
        #expect(playback.contains { $0.kind == "musicplay" && $0.payload == "daft punk" })
        #expect(Search.results(for: "music", context: context).contains { $0.id == "sys:musicplaypause" })
    }

    @Test func disabledSystemCommandIsHidden() {
        var context = SearchContext()
        context.preferences.systemDisabled = ["sleep"]
        #expect(!Search.results(for: "sleep", context: context).contains { $0.id == "sys:sleep" })
        context.preferences.systemDisabled = []
        #expect(Search.results(for: "sleep", context: context).contains { $0.id == "sys:sleep" })
    }

    @Test func clipboardClearKeyword() {
        var context = SearchContext()
        context.preferences.clipboardEnabled = true
        context.preferences.clipboardClearKeywordEnabled = true
        let all = Search.results(for: "clear", context: context)
        #expect(all.contains { $0.kind == "clipclear" && $0.payload == "all" })
        let five = Search.results(for: "clear 5", context: context)
        #expect(five.contains { $0.kind == "clipclear" && $0.payload == "5" })
        context.preferences.clipboardClearKeywordEnabled = false
        #expect(!Search.results(for: "clear", context: context).contains { $0.kind == "clipclear" })
    }

    @Test func contactDisplayOptions() {
        var context = SearchContext()
        context.preferences.contactsEnabled = true
        context.preferences.contactsInvertName = true
        context.preferences.contactsShowJobTitle = true
        context.contacts = [
            ContactRecord(id: "ada", name: "Ada Lovelace", email: "ada@example.com", phone: "", uid: "ada", jobTitle: "Mathematician"),
        ]
        let row = Search.results(for: "ada", context: context).first { $0.kind == "contact" }
        #expect(row?.title == "Lovelace, Ada")
        #expect(row?.subtitle.contains("Mathematician") == true)
    }

    @Test func ejectAllRespectsEnableSwitch() {
        var context = SearchContext()
        context.preferences.ejectAllEnabled = false
        #expect(!Search.results(for: "ejectall", context: context).contains { $0.id == "sys:ejectall" })
        context.preferences.ejectAllEnabled = true
        #expect(Search.results(for: "ejectall", context: context).contains { $0.id == "sys:ejectall" })
    }

    @Test func fileBrowserListsDirectoriesFirst() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("jfred-browser-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Folder"), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: root.appendingPathComponent("beta.txt"))
        try Data("x".utf8).write(to: root.appendingPathComponent("alpha.txt"))
        let entries = FileBrowser.entries(for: root.path + "/")
        #expect(entries?.first?.isDirectory == true)
        #expect(entries?.first?.name == "Folder")
        #expect(entries?.contains { $0.name == "alpha.txt" } == true)
        #expect(FileBrowser.entries(for: root.path + "/al")?.map(\.name) == ["alpha.txt"])
        #expect(FileBrowser.entries(for: "not/a/path") == nil)
    }

    @Test func clipboardViewerIncludesSnippets() {
        var context = SearchContext()
        context.preferences.clipboardEnabled = true
        context.preferences.clipboardSnippetsAtTop = true
        context.preferences.clipboardSnippetsWhenSearching = true
        context.snippets = [Snippet(name: "Address", keyword: ";addr", text: "1 Infinite Loop", autoExpand: true)]
        let all = Search.results(for: "clipboard", context: context)
        #expect(all.contains { $0.id == "snippets:all" })
        let filtered = Search.results(for: "clipboard infinite", context: context)
        #expect(filtered.contains { $0.kind == "snippet" && $0.title == "Address" })
    }

    @Test func customTerminalPrefix() {
        var context = SearchContext()
        context.preferences.terminalPrefix = "!"
        let rows = Search.results(for: "!echo hi", context: context)
        #expect(rows.first?.kind == "terminal")
        #expect(rows.first?.payload == "echo hi")
    }

    @Test func newPreferencesRoundTrip() throws {
        var prefs = Preferences()
        prefs.contactsEnabled = false
        prefs.musicKeyword = "tunes"
        prefs.clipboardAutoPaste = false
        prefs.fileBufferTimeoutMinutes = 9
        prefs.calculatorOutputThousands = false
        prefs.dictionaryDefineKeyword = "lookup"
        prefs.terminalPrefix = "!"
        prefs.uaShowRightArrow = false
        prefs.uaSelectionHotkey = "⌥⌘K"
        prefs.snippetExpandPlaySound = false
        prefs.clipboardIgnoreApps = ["Keychain Access", "CustomApp"]
        prefs.clipboardRetentionImages = "1 week"
        prefs.contactsEmailMode = "gmail"
        prefs.customThemes = [CustomTheme(name: "Test Theme", width: 600)]
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(Preferences.self, from: data)
        #expect(decoded.contactsEnabled == false)
        #expect(decoded.musicKeyword == "tunes")
        #expect(decoded.clipboardAutoPaste == false)
        #expect(decoded.fileBufferTimeoutMinutes == 9)
        #expect(decoded.calculatorOutputThousands == false)
        #expect(decoded.dictionaryDefineKeyword == "lookup")
        #expect(decoded.terminalPrefix == "!")
        #expect(decoded.uaShowRightArrow == false)
        #expect(decoded.uaSelectionHotkey == "⌥⌘K")
        #expect(decoded.snippetExpandPlaySound == false)
        #expect(decoded.clipboardIgnoreApps == ["Keychain Access", "CustomApp"])
        #expect(decoded.clipboardRetentionImages == "1 week")
        #expect(decoded.contactsEmailMode == "gmail")
        #expect(decoded.customThemes.first?.name == "Test Theme")
        #expect(decoded.customThemes.first?.width == 600)
    }

@Test func updateVersionsAndOfficialURLs() {
    #expect(AppVersion.compare("0.9.0", "0.10.0") == .orderedAscending)
    #expect(AppVersion.compare("v0.14.0", "0.14.0") == .orderedSame)
    #expect(AppVersion.compare("0.14.0", "0.14.0-beta") == .orderedDescending)
    #expect(AppVersion.compare("nope", "1.0.0") == nil)
    #expect(AppUpdateFeed.version(fromTag: "v0.14.0") == "0.14.0")
    #expect(AppUpdateFeed.version(fromTag: "0.14.0-beta") == nil)
    let url = URL(string: "https://github.com/weijing24/Jfred/releases/download/v0.14.0/Jfred-0.14.0-arm64.dmg")!
    #expect(AppUpdateFeed.isOfficialAssetURL(url, version: "0.14.0", architecture: "arm64"))
    #expect(!AppUpdateFeed.isOfficialAssetURL(url, version: "0.14.0", architecture: "x86_64"))
    #expect(!AppUpdateFeed.isOfficialAssetURL(URL(string: "http://github.com/weijing24/Jfred/releases/download/v0.14.0/Jfred-0.14.0-arm64.dmg")!, version: "0.14.0", architecture: "arm64"))
    #expect(!AppUpdateFeed.isOfficialAssetURL(URL(string: "https://github.com.evil/weijing24/Jfred/releases/download/v0.14.0/Jfred-0.14.0-arm64.dmg")!, version: "0.14.0", architecture: "arm64"))
    #expect(!AppUpdateFeed.isOfficialAssetURL(URL(string: "https://evilgithub.com/weijing24/Jfred/releases/download/v0.14.0/Jfred-0.14.0-arm64.dmg")!, version: "0.14.0", architecture: "arm64"))
    #expect(!AppUpdateFeed.isOfficialAssetURL(URL(string: "https://github.com/weijing24/Jfred/releases/download/v0.14.0/Jfred-0.14.0-arm64.dmg.evil")!, version: "0.14.0", architecture: "arm64"))
    #expect(!AppUpdateFeed.isOfficialAssetURL(URL(string: "https://github.com/other/Jfred/releases/download/v0.14.0/Jfred-0.14.0-arm64.dmg")!, version: "0.14.0", architecture: "arm64"))
    #expect(!AppUpdateFeed.isAllowedAssetHost("release-assets.githubusercontent.com.evil"))
    #expect(AppUpdateFeed.isAllowedAssetHost("release-assets.githubusercontent.com"))
    #expect(!AppUpdateFeed.isAllowedAPIHost("github.com"))
    #expect(UpdatePaths.isInstallableBundlePath("/Applications/Jfred.app"))
    #expect(!UpdatePaths.isInstallableBundlePath("/Volumes/Jfred/Jfred.app"))
    #expect(!UpdatePaths.isInstallableBundlePath("/private/var/folders/xx/AppTranslocation/ABC/d/Jfred.app"))
    #expect(!UpdatePaths.isInstallableBundlePath("/Applications/Other.app"))
    #expect(!UpdatePaths.isInstallableBundlePath("/tmp/Jfred.app\n/Applications/Jfred.app"))
}

@Test func updateFeedSelectsTheMatchingRelease() throws {
    let sha = String(repeating: "ab", count: 32)
    let feed = """
    [
      {"tag_name":"v0.15.0","draft":true,"prerelease":false,"body":"draft","assets":[\(asset("0.15.0", sha, 10))]},
      {"tag_name":"v0.14.0-beta","prerelease":true,"body":"skip tag","assets":[\(asset("0.14.0-beta", sha, 10))]},
      {"tag_name":"v0.16.0","prerelease":true,"body":"pre","assets":[\(asset("0.16.0", sha, 10)),{"name":"notes.txt","browser_download_url":"https://evil.example/x","size":4,"digest":"sha256:\(sha)"}]},
      {"tag_name":"v0.13.0","prerelease":false,"body":"old","assets":[\(asset("0.13.0", sha, 10))]},
      {"tag_name":"v0.12.0","prerelease":false,"body":"bad","assets":[{"name":"Jfred-0.12.0-arm64.dmg","browser_download_url":"https://github.com/weijing24/Jfred/releases/download/v0.12.0/Jfred-0.12.0-arm64.dmg","size":10,"digest":"md5:\(sha)"}]},
      {"tag_name":"v0.11.0","prerelease":false,"body":"huge","assets":[{"name":"Jfred-0.11.0-arm64.dmg","browser_download_url":"https://github.com/weijing24/Jfred/releases/download/v0.11.0/Jfred-0.11.0-arm64.dmg","size":\(AppUpdateFeed.maxAssetBytes + 1),"digest":"sha256:\(sha)"}]},
      {"tag_name":"v0.14.0","prerelease":false,"body":"stable notes","assets":[\(asset("0.14.0", sha, 20, architecture: "x86_64")),\(asset("0.14.0", sha, 30))]}
    ]
    """
    let catalog = try AppUpdateFeed.parse(Data(feed.utf8), architecture: "arm64")
    #expect(catalog.publishedCount == 5)
    #expect(catalog.releases.map(\.version) == ["0.16.0", "0.13.0", "0.14.0"])
    #expect(catalog.releases.first { $0.version == "0.14.0" }?.asset.byteCount == 30)
    #expect(catalog.releases.first { $0.version == "0.14.0" }?.asset.sha256 == sha)
    let stable = AppUpdateFeed.offer(in: catalog, channel: .updates, current: "0.14.0")
    guard case .upToDate(_, let notes) = stable else {
        Issue.record("expected the installed stable release")
        return
    }
    #expect(notes == "stable notes")
    let behind = AppUpdateFeed.offer(in: catalog, channel: .updates, current: "0.13.0")
    guard case .available(let release) = behind else {
        Issue.record("expected 0.14.0")
        return
    }
    #expect(release.version == "0.14.0")
    let pre = AppUpdateFeed.offer(in: catalog, channel: .prereleases, current: "0.14.0")
    guard case .available(let preview) = pre else {
        Issue.record("expected the pre-release")
        return
    }
    #expect(preview.version == "0.16.0")
    #expect(preview.prerelease)
    let ahead = AppUpdateFeed.offer(in: catalog, channel: .updates, current: "9.0.0")
    guard case .upToDate = ahead else {
        Issue.record("a newer local build is up to date")
        return
    }
    let empty = try AppUpdateFeed.parse(Data("[]".utf8), architecture: "arm64")
    guard case .unavailable = AppUpdateFeed.offer(in: empty, channel: .updates, current: "0.14.0") else {
        Issue.record("expected no releases")
        return
    }
    #expect(throws: UpdateFeedError.self) {
        try AppUpdateFeed.parse(Data("{}".utf8), architecture: "arm64")
    }
    let long = String(repeating: "n", count: AppUpdateFeed.notesLimit + 5)
    let clipped = try AppUpdateFeed.parse(Data("""
    [{"tag_name":"v1.0.0","body":"\(long)","assets":[\(asset("1.0.0", sha, 10))]}]
    """.utf8), architecture: "arm64")
    #expect(clipped.releases[0].notes.hasSuffix("\n…"))
    #expect(clipped.releases[0].notes.count == AppUpdateFeed.notesLimit + 2)
}

@Test func updateChecksumMatchesFileBytes() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("jfred-hash-\(UUID().uuidString)")
    try Data("hello".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(try UpdateChecksum.sha256Hex(file: url) == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    #expect(UpdateChecksum.matches(file: url, sha256: "2CF24DBA5FB0A30E26E83B2AC5B9E29E1B161E5C1FA7425E73043362938B9824"))
    #expect(!UpdateChecksum.matches(file: url, sha256: String(repeating: "ab", count: 32)))
}

@Test func liveGitHubFeedParsesWhenRequested() async throws {
    guard ProcessInfo.processInfo.environment["JFRED_UPDATE_LIVE"] == "1" else { return }
    var request = URLRequest(url: AppUpdateFeed.releasesURL())
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    request.setValue("Jfred-test", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode
    #expect(status == 200)
    let catalog = try AppUpdateFeed.parse(data, architecture: "arm64")
    #expect(!catalog.releases.isEmpty)
    guard case .available(let release) = AppUpdateFeed.offer(in: catalog, channel: .updates, current: "0.0.0") else {
        Issue.record("expected a published update")
        return
    }
    #expect(AppUpdateFeed.isOfficialAssetURL(release.asset.downloadURL, version: release.version, architecture: "arm64"))
    guard case .upToDate = AppUpdateFeed.offer(in: catalog, channel: .updates, current: "999.0.0") else {
        Issue.record("a future version should be current")
        return
    }
}

private func asset(_ version: String, _ sha: String, _ size: Int64, architecture: String = "arm64") -> String {
    let name = AppUpdateFeed.assetName(version: version, architecture: architecture)
    return #"{"name":"\#(name)","browser_download_url":"https://github.com/weijing24/Jfred/releases/download/v\#(version)/\#(name)","size":\#(size),"digest":"sha256:\#(sha)"}"#
}
