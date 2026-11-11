import Foundation
import Testing
@testable import JfredCore

/// `fieldMatch(query:target:)` as it was before match keys were prepared ahead
/// of time. The prepared path must return exactly this, tier and score.
private func referenceFieldMatch(query: String, target: String) -> FieldMatch? {
    let q = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
    let t = fold(target)
    if q.isEmpty || t.isEmpty { return nil }
    if t == q { return FieldMatch(tier: 0, score: 1) }

    var tier: Int?
    var score = 0.0
    if t.hasPrefix(q) {
        tier = 1
        score = 0.97
    }
    let words = t.split { !$0.isLetter && !$0.isNumber }
    if words.contains(where: { $0.hasPrefix(q) }) {
        if tier == nil { tier = 2 }
        score = max(score, 0.93)
    }
    let initials = camelInitials(target)
    if !initials.isEmpty, fold(initials).hasPrefix(q), q.count >= 2 {
        if tier == nil { tier = 2 }
        score = max(score, 0.91)
    }
    if t.contains(q) {
        if tier == nil { tier = 3 }
        score = max(score, 0.84)
    }

    var index = t.startIndex
    var streak = 0
    var raw = 0.0
    var fuzzy = true
    for character in q {
        guard let found = t[index...].firstIndex(of: character) else {
            fuzzy = false
            break
        }
        let distance = t.distance(from: index, to: found)
        let atBoundary = found == t.startIndex || !t[t.index(before: found)].isLetter
        streak = distance == 0 ? streak + 1 : 1
        raw += 1 + Double(streak) * 0.18 + (atBoundary ? 0.25 : 0) - Double(distance) * 0.03
        index = t.index(after: found)
    }
    if fuzzy {
        let subsequence = min(0.9, raw / (Double(q.count) * 2.1))
        if tier == nil {
            guard subsequence > 0 else { return nil }
            tier = 4
            score = subsequence
        } else {
            score = max(score, subsequence)
        }
    }
    guard let tier, score > 0 else { return nil }
    return FieldMatch(tier: tier, score: score - Double(t.count) * 0.0015)
}

private let matchTargets: [String] = {
    var targets = [
        "", " ", "   ", "\t\n",
        "a", "ab", "Safari", "safari", "SAFARI", "Local", "Calendar", "System Settings",
        "HostPane", "Hostpane", "Host Pane", "hostPane", "XMLHttpRequest", "iTerm2", "1Password 7",
        "Google Chrome", "Visual Studio Code", "Microsoft Word", "Claude Code URL Handler",
        "Café Résumé", "Crème Brûlée", "naïve façade", "Ångström", "ÉCOLE", "e\u{301}cole", "Straße",
        "Ünïcödé Wörds", "Привет Мир", "ΑΒΓ alpha",
        "微信", "网易云音乐", "企业微信", "QQ音乐", "Git - 打标签", "日本語のテキスト", "한국어",
        "weixin", "wx", "wei xin", "wangyiyunyinyue", "wyyyy",
        "https://github.com/jim/jfred",
        "https://gitlab.com/gitlab-org/gitlab-runner/issues/3492",
        "http://www.example.com/path?query=a&b=c#frag",
        "https://git-scm.com/book/zh/v1/Git-%E5%9F%BA%E7%A1%80-%E6%89%93%E6%A0%87%E7%AD%BE",
        "mailto:someone@example.com", "file:///Users/me/Documents/Report.pdf",
        "x-apple.systempreferences:com.apple.Sharing-Settings.extension",
        "Jira Software", "JIRA-1234 Fix login", "emoji 🚀 rocket", "x\r\ny", "tab\tseparated  words",
    ]
    for name in ["微信", "网易云音乐", "企业微信", "QQ音乐", "Git - 打标签"] {
        targets += pinyinVariants(name)
        targets += matchFields(forName: name)
    }
    return targets
}()

private let matchQueries: [String] = {
    var queries = [
        "", " ", "\t", "a", "s", "sa", "saf", "safari", "Safari", "SAF", " saf ", "sfr",
        "hp", "hos", "host p", "hostpane", "gc", "vsc", "code", "it", "iterm", "1p", "pass", "mw",
        "xml", "xhr", "http", "cafe", "café", "CAFE", "resume", "creme", "naive", "facade",
        "angstrom", "ecole", "école", "strasse", "straße", "unicode", "при", "мир", "αβ", "alpha",
        "微", "微信", "wx", "weixin", "wei", "wyy", "wangyi", "yinyue", "qq", "标签", "日本", "한",
        "git", "gi", "github", "gtlb", "jira", "j", "jfred", "com", ".com", "://", "/", "issues", "3492",
        "x", "e", "o", "lo", "cal", "local", "sys", "ss", "set", "settings", "🚀", "rocket",
        "zzz", "qz", "ae", "x\r", "tab sep", "cuh",
    ]
    // Prefixes, initials and skip-one subsequences of every target reach every tier.
    for target in matchTargets {
        let characters = Array(target)
        for length in 1...3 where characters.count >= length {
            queries.append(String(characters.prefix(length)))
        }
        queries.append(camelInitials(target))
        queries.append(String(characters.enumerated().filter { $0.offset % 2 == 0 }.map(\.element).prefix(6)))
        if characters.count > 4 {
            queries.append(String(characters[2..<min(characters.count, 6)]))
        }
    }
    var seen = Set<String>()
    return queries.filter { seen.insert($0).inserted }
}()

struct SearchIndexTests {
    @Test func preparedFieldMatchEqualsReference() {
        let keys = matchTargets.map { ($0, MatchKey($0)) }
        var tiers = Set<Int>()
        var mismatches: [String] = []
        for query in matchQueries {
            let prepared = MatchQuery(query)
            for (target, key) in keys {
                let expected = referenceFieldMatch(query: query, target: target)
                if let expected { tiers.insert(expected.tier) }
                if fieldMatch(query: prepared, key: key) != expected
                    || fieldMatch(query: query, target: target) != expected {
                    mismatches.append("\(query.debugDescription) vs \(target.debugDescription)")
                }
                for maxTier in 0...4 {
                    let kept = expected.flatMap { $0.tier <= maxTier ? $0 : nil }
                    if fieldMatch(query: prepared, key: key, maxTier: maxTier) != kept {
                        mismatches.append("\(query.debugDescription) vs \(target.debugDescription) maxTier \(maxTier)")
                    }
                }
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.prefix(20))")
        #expect(tiers == [0, 1, 2, 3, 4])
    }

    @Test func bestPreparedMatchEqualsReference() {
        let fieldSets: [[String]] = [
            ["Safari", "safari"],
            matchFields(forName: "微信"),
            matchFields(forName: "HostPane", aliases: ["Host Pane"]),
            ["Safari Release Notes", "https://developer.apple.com/safari/notes"],
            ["", "Sample"],
            ["Local", "Calendar"],
        ]
        for fields in fieldSets {
            let keys = fields.map(MatchKey.init)
            for query in matchQueries {
                let expected = fields.compactMap { referenceFieldMatch(query: query, target: $0) }.min { lhs, rhs in
                    if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
                    return lhs.score > rhs.score
                }
                #expect(bestFieldMatch(query: MatchQuery(query), keys: keys) == expected)
                #expect(bestFieldMatch(query: query, fields: fields) == expected)
                #expect(bestFieldMatch(query: MatchQuery(query), keys: keys, maxTier: 2) == expected.flatMap { $0.tier <= 2 ? $0 : nil })
            }
        }
    }

    @Test func staleIndexStillReflectsCurrentRecords() {
        var context = SearchContext()
        context.apps = [AppRecord(id: "safari", name: "Safari", path: "/Applications/Safari.app")]
        context.links = [LinkRecord(id: "old", title: "Old Site", url: "https://old.example.com", source: "Safari")]
        context.snippets = [Snippet(name: "Old Snippet", keyword: "olds", text: "x")]
        context.workflows = [Workflow(name: "Old Flow", keyword: "oldf")]
        var index = SearchIndex()
        index.refresh(for: context)
        #expect(index.isCurrent(for: context))

        context.apps.append(AppRecord(id: "wechat", name: "微信", path: "/Applications/WeChat.app"))
        context.links.append(LinkRecord(id: "new", title: "Neon Docs", url: "https://neon.example.com", source: "Chrome"))
        context.snippets.append(Snippet(name: "Neat Snippet", keyword: "neat", text: "y"))
        context.workflows.append(Workflow(name: "Nebula Flow", keyword: "neb"))
        context.preferences.systemKeywords = ["sleep": "nap"]
        #expect(!index.isCurrent(for: context))

        context.index = index
        var unindexed = context
        unindexed.index = nil
        for query in ["ne", "neb", "nap", "old", "wx", "weixin"] {
            #expect(Search.results(for: query, context: context) == Search.results(for: query, context: unindexed))
        }
        let ne = Search.results(for: "ne", context: context).map(\.id)
        #expect(ne.contains("link:new"))
        #expect(ne.contains { $0.hasPrefix("snip:") })
        #expect(ne.contains { $0.hasPrefix("complete:") })
        #expect(Search.results(for: "nap", context: context).contains { $0.id == "sys:sleep" })
        // Apps without stored aliases still match by pinyin.
        if let initials = pinyinVariants("微信").last, initials.count >= 2 {
            #expect(Search.results(for: initials, context: context).contains { $0.title == "微信" })
        }

        index.refresh(for: context)
        #expect(index.isCurrent(for: context))
    }

    @Test func rankingOrderIsPinned() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var context = SearchContext(now: now)
        context.apps = [
            AppRecord(id: "safari", name: "Safari", path: "/Applications/Safari.app"),
            AppRecord(id: "stp", name: "Safari Technology Preview", path: "/Applications/Safari Technology Preview.app"),
            AppRecord(id: "safekeep", name: "SafeKeep", path: "/Users/me/Applications/SafeKeep.app"),
            AppRecord(id: "soundsafe", name: "Sound Safe", path: "/System/Applications/Sound Safe.app"),
            AppRecord(id: "sa", name: "SystemAudit", path: "/Applications/SystemAudit.app"),
            AppRecord(id: "calendar", name: "Calendar", path: "/System/Applications/Calendar.app"),
        ]
        context.settings = [
            SettingRecord(id: "safety", name: "Safety Check", url: "x-apple.systempreferences:safety"),
            SettingRecord(id: "sound", name: "Sound", url: "x-apple.systempreferences:sound"),
        ]
        context.links = [
            LinkRecord(id: "notes", title: "Safari Release Notes", url: "https://developer.apple.com/safari/notes", source: "Safari"),
            LinkRecord(id: "sample", title: "Sample Site", url: "https://sample.example.com", source: "Chrome"),
            LinkRecord(id: "mesa", title: "Mesa Docs", url: "https://docs.mesa3d.org/safety.html", source: "Chrome"),
            LinkRecord(id: "dup", title: "Safari Release Notes", url: "https://developer.apple.com/safari/notes", source: "Safari"),
        ]
        let pitch = "00000000-0000-0000-0000-000000000001"
        let signature = "00000000-0000-0000-0000-000000000002"
        context.snippets = [
            Snippet(id: UUID(uuidString: pitch)!, name: "Sales Pitch", keyword: "sp", text: "Hello"),
            Snippet(id: UUID(uuidString: signature)!, name: "Signature", keyword: "saf", text: "Best"),
        ]
        context.selections = [
            "link:sample": SelectionStat(count: 9, lastSelected: now.addingTimeInterval(-3600)),
            "app:/Users/me/Applications/SafeKeep.app": SelectionStat(count: 3, lastSelected: now.addingTimeInterval(-86_400)),
            "app:/Applications/Safari Technology Preview.app": SelectionStat(count: 1, lastSelected: now.addingTimeInterval(-30 * 86_400)),
        ]
        context.knowledge = ["sa": "link:mesa", "saf": "snip:\(signature)"]

        // Band (apps in /Applications that contain the query, other apps that
        // contain it, settings, other /Applications apps, other apps, the rest),
        // then the latched result, tier, score plus frecency, and title.
        let apps = [
            "app:/Applications/Safari.app",
            "app:/Applications/Safari Technology Preview.app",
            "app:/Users/me/Applications/SafeKeep.app",
            "app:/System/Applications/Sound Safe.app",
        ]
        #expect(Search.results(for: "sa", context: context).map(\.id) == apps + [
            "set:safety", "app:/Applications/SystemAudit.app",
            "link:mesa", "link:sample", "snip:\(signature)", "snip:\(pitch)", "link:notes", "link:dup", "sys:screensaver",
        ])
        #expect(Search.results(for: "saf", context: context).map(\.id) == apps + [
            "set:safety", "snip:\(signature)", "link:notes", "link:dup", "link:mesa",
        ])
        #expect(Search.results(for: "safari", context: context).map(\.id) == [
            "app:/Applications/Safari.app", "app:/Applications/Safari Technology Preview.app", "link:notes", "link:dup",
        ])
        #expect(Search.results(for: "so", context: context).map(\.id) == ["app:/System/Applications/Sound Safe.app", "set:sound"])

        context.preferences.topResultLatching = false
        #expect(Search.results(for: "sa", context: context).map(\.id) == apps + [
            "set:safety", "app:/Applications/SystemAudit.app",
            "link:sample", "snip:\(signature)", "snip:\(pitch)", "link:notes", "link:dup", "sys:screensaver", "link:mesa",
        ])
    }

    @Test func volumeCommandParsing() {
        let context = SearchContext()
        #expect(Search.results(for: "vol 30", context: context).map(\.id) == ["sys:volume:30"])
        #expect(Search.results(for: "VOLUME 100", context: context).map(\.id) == ["sys:volume:100"])
        #expect(!Search.results(for: "volume 101", context: context).contains { $0.id.hasPrefix("sys:volume:") })
        #expect(!Search.results(for: "vol", context: context).contains { $0.id.hasPrefix("sys:volume:") })
    }
}
