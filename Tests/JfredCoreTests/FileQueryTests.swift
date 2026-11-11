import Foundation
import Testing
@testable import JfredCore

struct SpotlightPredicateTests {
    @Test func escapesQuotesBackslashesAndWildcards() {
        #expect(SpotlightPredicate.escape(#"a"b\c*d?e'f"#) == #"a\"b\\c\*d\?e'f"#)
        #expect(SpotlightPredicate.escape("plain café") == "plain café")
    }

    @Test func nameQueryRequiresEveryTermAsAWordPrefix() {
        let predicate = SpotlightPredicate.make(for: FileQuery(kind: .name, text: " apple\twallet  "))
        #expect(predicate == #"kMDItemFSName == "apple*"cdw && kMDItemFSName == "wallet*"cdw"#)
    }

    @Test func termsAreEscapedInsideThePredicate() {
        let predicate = SpotlightPredicate.make(for: FileQuery(kind: .name, text: #"1920*1080 say"hi"#))
        #expect(predicate == #"kMDItemFSName == "1920\*1080*"cdw && kMDItemFSName == "say\"hi*"cdw"#)
    }

    @Test func apostrophesSplitTheTerm() {
        #expect(SpotlightPredicate.make(for: FileQuery(kind: .name, text: "brenna o'brien"))
            == #"kMDItemFSName == "brenna*"cdw && kMDItemFSName == "brien*"cdw"#)
        #expect(SpotlightPredicate.make(for: FileQuery(kind: .name, text: "jim’s"))
            == #"kMDItemFSName == "jim*"cdw"#)
        #expect(SpotlightPredicate.make(for: FileQuery(kind: .name, text: "o'k"))
            == #"kMDItemFSName == "o*"cdw"#)
        #expect(SpotlightPredicate.make(for: FileQuery(kind: .name, text: "'")) == nil)
    }

    @Test func contentAndTagQueries() {
        #expect(SpotlightPredicate.make(for: FileQuery(kind: .content, text: "rabbit hat"))
            == #"kMDItemTextContent == "rabbit*"cdw && kMDItemTextContent == "hat*"cdw"#)
        #expect(SpotlightPredicate.make(for: FileQuery(kind: .tags, text: "red work"))
            == #"kMDItemUserTags == "red*"cd && kMDItemUserTags == "work*"cd"#)
    }

    @Test func emptyQueryHasNoPredicate() {
        #expect(SpotlightPredicate.make(for: FileQuery(kind: .name, text: "   ")) == nil)
        #expect(SpotlightPredicate.make(for: FileQuery(kind: .content, text: "")) == nil)
    }
}

struct FileScopeFilterTests {
    let filter = FileScopeFilter(roots: [
        "/Applications",
        "/Applications/Xcode.app/Contents/Applications",
        "/Users/me/workspace",
        "/Users/me/go",
        "/Users/me/.config/",
    ])

    @Test func keepsOrdinaryFiles() {
        #expect(!filter.excludes("/Users/me/workspace/app/README.md"))
        #expect(!filter.excludes("/Users/me/workspace"))
        #expect(!filter.excludes("/Applications/Safari.app"))
        #expect(!filter.excludes("/Users/me/go/src/tool/main.go"))
    }

    @Test func skipsDependencyAndBuildFolders() {
        #expect(filter.excludes("/Users/me/workspace/site/node_modules/left-pad/index.js"))
        #expect(filter.excludes("/Users/me/workspace/site/node_modules"))
        #expect(filter.excludes("/Users/me/workspace/ios/Pods/Alamofire/Source.swift"))
        #expect(filter.excludes("/Users/me/workspace/DerivedData/Build/x.o"))
        #expect(filter.excludes("/Users/me/go/pkg/mod/golang.org/x/text@v0.25.0/main.go"))
        #expect(!filter.excludes("/Users/me/go/pkg/tool/readme.txt"))
    }

    @Test func skipsHiddenComponents() {
        #expect(filter.excludes("/Users/me/workspace/repo/.git/HEAD"))
        #expect(filter.excludes("/Users/me/workspace/repo/.build/debug/app"))
        #expect(filter.excludes("/Users/me/workspace/.env"))
    }

    @Test func skipsPackageContentsButKeepsThePackage() {
        #expect(filter.excludes("/Applications/Safari.app/Contents/Info.plist"))
        #expect(filter.excludes("/Users/me/workspace/Thing.prefPane/Contents/Resources/x.nib"))
        #expect(filter.excludes("/Users/me/workspace/Photos Library.photoslibrary/database/Photos.sqlite"))
        #expect(!filter.excludes("/Users/me/workspace/Thing.prefPane"))
    }

    @Test func onlyThePartBelowTheDeepestRootCounts() {
        #expect(!filter.excludes("/Applications/Xcode.app/Contents/Applications/Instruments.app"))
        #expect(filter.excludes("/Applications/Xcode.app/Contents/Developer/usr/bin/swift"))
        // A hidden scope root still returns its contents.
        #expect(!filter.excludes("/Users/me/.config/nvim/init.lua"))
        #expect(filter.excludes("/Users/me/.ssh/config"))
    }

    @Test func rootsCompareCaseInsensitively() {
        #expect(!filter.excludes("/applications/xcode.app/Contents/Applications/Simulator.app"))
        #expect(!filter.excludes("/Users/Me/Workspace/notes.txt"))
    }
}

struct FileSearchQueryTests {
    let prefs = Preferences()

    @Test func classifiesFileQueries() {
        #expect(Search.fileQuery(raw: " report", preferences: prefs) == FileQuery(kind: .name, text: "report"))
        #expect(Search.fileQuery(raw: "open annual report", preferences: prefs) == FileQuery(kind: .name, text: "annual report"))
        #expect(Search.fileQuery(raw: "find report", preferences: prefs) == FileQuery(kind: .name, text: "report"))
        #expect(Search.fileQuery(raw: "in rabbit from hat", preferences: prefs) == FileQuery(kind: .content, text: "rabbit from hat"))
        #expect(Search.fileQuery(raw: "tags magic tricks", preferences: prefs) == FileQuery(kind: .tags, text: "magic tricks"))
        #expect(Search.fileQuery(raw: "open", preferences: prefs) == FileQuery(kind: .name, text: ""))
        #expect(Search.fileQuery(raw: " ", preferences: prefs) == FileQuery(kind: .name, text: ""))
        #expect(Search.fileQuery(raw: "cal", preferences: prefs) == nil)
        #expect(Search.fileQuery(raw: "opener", preferences: prefs) == nil)
    }

    @Test func disabledKeywordsAreNotFileQueries() {
        var prefs = Preferences()
        prefs.quickSearchEnabled = false
        prefs.fileInsideEnabled = false
        #expect(Search.fileQuery(raw: " report", preferences: prefs) == nil)
        #expect(Search.fileQuery(raw: "in notes", preferences: prefs) == nil)
        #expect(!Search.exclusiveSlowQuery(raw: "in notes", preferences: prefs))
    }
}

struct FileResultRankingTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func context(_ files: [FileHit]) -> SearchContext {
        var context = SearchContext(now: now)
        context.files = files
        return context
    }

    @Test func keepsOnlyNameAndWordPrefixMatches() {
        let rows = Search.results(for: " port", context: context([
            FileHit(path: "/Users/me/Report.pdf", name: "Report.pdf"),
            FileHit(path: "/Users/me/port-forward.sh", name: "port-forward.sh"),
            FileHit(path: "/Users/me/Air Port Notes.txt", name: "Air Port Notes.txt"),
        ]))
        #expect(rows.map(\.title) == ["port-forward.sh", "Air Port Notes.txt"])
    }

    @Test func ranksByTierThenScore() {
        let rows = Search.results(for: "open report", context: context([
            FileHit(path: "/Users/me/Annual Report.pdf", name: "Annual Report.pdf"),
            FileHit(path: "/Users/me/report-2024-final.pdf", name: "report-2024-final.pdf"),
            FileHit(path: "/Users/me/report", name: "report"),
            FileHit(path: "/Users/me/report.pdf", name: "report.pdf"),
        ]))
        #expect(rows.map(\.title) == ["report", "report.pdf", "report-2024-final.pdf", "Annual Report.pdf"])
    }

    @Test func recencyReordersEqualMatchesOnly() {
        let day: TimeInterval = 24 * 3600
        let files = [
            FileHit(path: "/Users/me/notes-a.txt", name: "notes-a.txt"),
            FileHit(path: "/Users/me/notes-b.txt", name: "notes-b.txt", lastUsed: now.addingTimeInterval(-day)),
            FileHit(path: "/Users/me/old notes.txt", name: "old notes.txt", lastUsed: now),
        ]
        let rows = Search.results(for: " notes", context: context(files))
        // The recently used tier 2 match stays below both name prefix matches.
        #expect(rows.map(\.title) == ["notes-b.txt", "notes-a.txt", "old notes.txt"])
    }

    @Test func matchesTheFileNameWhenTheDisplayNameDiffers() {
        let rows = Search.results(for: " downloads", context: context([
            FileHit(path: "/Users/me/Downloads", name: "Téléchargements"),
        ]))
        #expect(rows.map(\.title) == ["Téléchargements"])
    }

    @Test func hiddenFileTypesStayOut() {
        var context = context([
            FileHit(path: "/Users/me/main.swift", name: "main.swift"),
            FileHit(path: "/Users/me/main.pdf", name: "main.pdf"),
        ])
        context.preferences.hiddenFileTypes = ["Source files"]
        #expect(Search.results(for: " main", context: context).map(\.title) == ["main.pdf"])
    }

    @Test func externalDrivesUseTypeIconsWhenAsked() {
        var context = context([FileHit(path: "/Volumes/Backup/report.pdf", name: "report.pdf")])
        #expect(Search.results(for: " report", context: context).first?.icon == "file:/Volumes/Backup/report.pdf")
        context.preferences.fileUseTypeIconsForExternal = true
        #expect(Search.results(for: " report", context: context).first?.icon == "symbol:doc")
    }

    @Test func recencyBoostIsSmallAndDecays() {
        #expect(FileRanking.recencyBoost(nil, now: now) == 0)
        #expect(FileRanking.recencyBoost(now, now: now) == FileRanking.recencyWeight)
        let twoWeeks = FileRanking.recencyBoost(now.addingTimeInterval(-FileRanking.recencyHalfLife), now: now)
        #expect(abs(twoWeeks - FileRanking.recencyWeight / 2) < 1e-9)
        // Smaller than the gap between a prefix match (0.97) and a word prefix match (0.93).
        #expect(FileRanking.recencyWeight < 0.04)
    }
}

struct FileCandidateRankingTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func ordersKeptCandidatesBestFirst() {
        let candidates = [
            FileCandidate(name: "Annual Report.pdf", fileName: "Annual Report.pdf"),
            FileCandidate(name: "Support.txt", fileName: "Support.txt"),
            FileCandidate(name: "report.pdf", fileName: "report.pdf"),
            FileCandidate(name: "report", fileName: "report"),
        ]
        let order = Search.rankFileCandidates(query: "report", candidates: candidates, preferences: Preferences(), now: now)
        #expect(order == [3, 2, 0])
    }

    @Test func skipsHiddenTypesBeforeResolvingPaths() {
        var prefs = Preferences()
        prefs.hiddenFileTypes = ["Images"]
        let candidates = [
            FileCandidate(name: "logo.png", fileName: "logo.png"),
            FileCandidate(name: "logo.svg.txt", fileName: "logo.svg.txt"),
        ]
        #expect(Search.rankFileCandidates(query: "logo", candidates: candidates, preferences: prefs, now: now) == [1])
    }

    @Test func recentFirstKeepsSpotlightOrderForTies() {
        let candidates = [
            FileCandidate(name: "a", fileName: "a"),
            FileCandidate(name: "b", fileName: "b", lastUsed: now),
            FileCandidate(name: "c", fileName: "c"),
            FileCandidate(name: "d", fileName: "d", lastUsed: now.addingTimeInterval(-60)),
        ]
        #expect(FileRanking.recentFirst(candidates) == [1, 3, 0, 2])
    }
}

struct ContentAndTagResultTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func emptyKeywordShowsAHint() {
        let rows = Search.results(for: "in", context: SearchContext(now: now))
        #expect(rows.map(\.id) == ["file:hint"])
        #expect(Search.results(for: "tags ", context: SearchContext(now: now)).map(\.id) == ["file:hint"])
    }

    @Test func contentRowsComeFromSpotlightRecentFirst() {
        var context = SearchContext(now: now)
        context.files = [
            FileHit(path: "/Users/me/b.txt", name: "b.txt"),
            FileHit(path: "/Users/me/a.txt", name: "a.txt"),
            FileHit(path: "/Users/me/z.txt", name: "z.txt", lastUsed: now),
        ]
        let rows = Search.results(for: "in rabbit", context: context)
        #expect(rows.map(\.title) == ["z.txt", "a.txt", "b.txt"])
        #expect(rows.allSatisfy { $0.kind == "file" })
    }

    @Test func contentSearchHonorsHiddenTypesButTagsDoNot() {
        var context = SearchContext(now: now)
        context.preferences.hiddenFileTypes = ["Emails"]
        context.files = [
            FileHit(path: "/Users/me/msg.eml", name: "msg.eml"),
            FileHit(path: "/Users/me/doc.txt", name: "doc.txt"),
        ]
        #expect(Search.results(for: "in rabbit", context: context).map(\.title) == ["doc.txt"])
        #expect(Search.results(for: "tags red", context: context).map(\.title) == ["doc.txt", "msg.eml"])
    }

    @Test func contentRowsRespectTheResultLimit() {
        var context = SearchContext(now: now)
        context.preferences.fileSearchMax = 15
        context.files = (0..<30).map { FileHit(path: "/Users/me/f\($0).txt", name: "f\($0).txt") }
        #expect(Search.results(for: "in rabbit", context: context).count == 15)
    }
}

struct FileQueryLaunchPolicyTests {
    @Test func shortNamePrefixesWaitBeforeReachingSpotlight() {
        #expect(FileQuery(kind: .name, text: "k").launchDelay == FileQuery.shortQueryDelay)
        #expect(FileQuery(kind: .name, text: "ke").launchDelay == FileQuery.shortQueryDelay)
        #expect(FileQuery(kind: .name, text: "ker").launchDelay == 0)
        #expect(FileQuery(kind: .name, text: "kernel").launchDelay == 0)
        // Every term reaches Spotlight, so one short term makes the query slow.
        #expect(FileQuery(kind: .name, text: "kernel ab").launchDelay == FileQuery.shortQueryDelay)
        #expect(FileQuery(kind: .name, text: "   ").launchDelay == 0)
    }

    @Test func onlyNameQueriesWait() {
        #expect(FileQuery(kind: .content, text: "ab").launchDelay == 0)
        #expect(FileQuery(kind: .tags, text: "r").launchDelay == 0)
    }

    @Test func apostrophePiecesCountAsTheyReachSpotlight() {
        // "o'k" asks Spotlight for "o" only.
        #expect(FileQuery(kind: .name, text: "o'k").launchDelay == FileQuery.shortQueryDelay)
        #expect(FileQuery(kind: .name, text: "brenna o'brien").launchDelay == 0)
    }

    @Test func singleCharacterQueriesReadFewerCandidates() {
        #expect(FileQuery(kind: .name, text: "k").candidateLimit == FileQuery.singleCharacterCandidateLimit)
        #expect(FileQuery(kind: .name, text: "a b").candidateLimit == FileQuery.singleCharacterCandidateLimit)
        #expect(FileQuery(kind: .name, text: "ke").candidateLimit == FileQuery.nameCandidateLimit)
        #expect(FileQuery(kind: .name, text: "kernel a").candidateLimit == FileQuery.nameCandidateLimit)
        #expect(FileQuery(kind: .content, text: "a").candidateLimit == FileQuery.otherCandidateLimit)
        #expect(FileQuery(kind: .tags, text: "red").candidateLimit == FileQuery.otherCandidateLimit)
    }
}
