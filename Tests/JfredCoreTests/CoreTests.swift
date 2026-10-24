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

    @Test func epochAndDev() {
        let rows = Epoch.rows(argument: "1700000000", now: Date(timeIntervalSince1970: 0))
        #expect(rows.contains { $0.payload == "1700000000" })
        let uuid = DevToys.rows(argument: "uuid")
        #expect(uuid.count == 1)
        #expect(!uuid[0].payload.isEmpty)
        let hash = DevToys.rows(argument: "sha256 abc")
        #expect(hash[0].payload == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
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
        context.workflows = [
            Workflow(name: "Kill Process", keyword: "kill", author: "Built in", symbol: "xmark.octagon", tint: "red", builtin: "kill"),
        ]
        context.processes = [ProcInfo(pid: 42, name: "Safari")]
        let co = Search.results(for: "co", context: context).map(\.title)
        #expect(co.contains("Computer"))
        #expect(co.contains("Console"))
        #expect(co.contains("Contacts"))
        #expect(co.firstIndex(of: "Contacts")! < co.firstIndex(of: "Computer")!)
        #expect(co.firstIndex(of: "Console")! < co.firstIndex(of: "Computer")!)

        let kill = Search.results(for: "kill", context: context)
        #expect(kill.first?.kind == "process")
        #expect(kill.first?.title == "Safari")

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
        #expect(fieldMatch(query: "cal", target: "Local")?.tier == 4)
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

    @Test func launcherKeywords() {
        let dev = Workflow(name: "DevToys", keyword: "encode", author: "Built in", symbol: "hammer", tint: "purple", builtin: "dev")
        let epoch = Workflow(name: "Epoch Converter", keyword: "ts", author: "Built in", symbol: "clock", tint: "blue", builtin: "epoch")
        let unit = Workflow(name: "Unit Converter", keyword: "conv", author: "Built in", symbol: "ruler", tint: "yellow", builtin: "unit")
        let profiles = Workflow(name: "Switch Chrome Profiles", keyword: "cp", author: "Built in", symbol: "person", tint: "purple", builtin: "profiles")
        let windows = Workflow(name: "Window Switcher", keyword: "win", author: "Built in", symbol: "macwindow", tint: "orange", enabled: false, builtin: "windows")
        var context = SearchContext(workflows: [dev, epoch, unit, profiles, windows])
        let encoded = Search.results(for: "encode hi", context: context)
        #expect(encoded.contains { $0.payload == "aGk=" })
        let snake = Search.results(for: "cc snake Hello World", context: context)
        #expect(snake.first?.payload == "hello_world")
        let stamp = Search.results(for: "ts 1700000000", context: context)
        #expect(stamp.contains { $0.payload == "1700000000" })
        let converted = Search.results(for: "conv 10 km in m", context: context)
        #expect(converted.first?.title == "10000 m")
        context.profiles = [ProfileInfo(id: "Default", name: "Default", directory: "Default")]
        let profile = Search.results(for: "cpDef", context: context)
        #expect(profile.first?.kind == "profile")
        #expect(profile.first?.title == "Default")
        context.windows = [WindowInfo(id: "1", title: "Inbox", owner: "Mail", pid: 1)]
        let win = Search.results(for: "win", context: context)
        #expect(!win.contains { $0.kind == "window" })
        let base64 = DevToys.rows(keyword: "nb decimal", argument: "255")
        #expect(base64.contains { $0.payload == "FF" })
        let parsed = ScriptJSON.items(in: "log\n{\"items\":[{\"title\":\"A\",\"subtitle\":\"B\",\"arg\":\"C\"}]}\n")
        #expect(parsed?.first?.title == "A")
        #expect(parsed?.first?.valid == true)
        let id = UUID()
        let data = #"{"id":"\#(id.uuidString)","name":"Date","keyword":";date","text":"{date}"}"#.data(using: .utf8)!
        let snippet = try! JSONDecoder().decode(Snippet.self, from: data)
        #expect(snippet.autoExpand)
        #expect(snippet.keyword == ";date")
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
