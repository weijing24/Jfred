import Foundation
import Testing
@testable import JfredCore

/// `expandTokens(_:now:)` as it was before snippet placeholders grew. Existing
/// tokens must expand exactly as they did.
private func referenceExpandTokens(_ text: String, now: Date) -> String {
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

struct SnippetTokensTests {
    /// 2026-03-04 05:06:07 UTC.
    private let now = Date(timeIntervalSince1970: 1_772_600_767)
    private let utc = TimeZone(identifier: "UTC")!
    private let shanghai = TimeZone(identifier: "Asia/Shanghai")!
    private let posix = Locale(identifier: "en_US_POSIX")
    private let english = Locale(identifier: "en_US")

    private func expand(_ text: String, clipboard: String? = nil, locale: Locale? = nil, timeZone: TimeZone? = nil) -> SnippetExpansion {
        expandSnippet(text, now: now, clipboard: clipboard, locale: locale ?? posix, timeZone: timeZone ?? utc)
    }

    private func styled(_ date: DateFormatter.Style, _ time: DateFormatter.Style, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = date
        formatter.timeStyle = time
        return formatter.string(from: now)
    }

    @Test func fixedDateIsWhatTheTestsAssume() {
        #expect(ISO8601DateFormatter().string(from: now) == "2026-03-04T05:06:07Z")
    }

    @Test func existingTokensExpandAsBefore() {
        let templates = [
            "Today is {date}",
            "{time} sharp",
            "Stamp {iso}",
            "Re: {clipboard}!",
            "{date} {time} {iso} {clipboard}",
            "no tokens here",
            "{Date} {DATE} { date }",
        ]
        for template in templates {
            #expect(expandSnippet(template, now: now).text == referenceExpandTokens(template, now: now), "\(template)")
            #expect(expandSnippet(template, now: now).cursorOffset == 0)
        }
    }

    @Test func plainDateTokensUseMediumDateAndShortTime() {
        #expect(expand("{date}", locale: english).text == styled(.medium, .none, locale: english, timeZone: utc))
        #expect(expand("{time}", locale: english).text == styled(.none, .short, locale: english, timeZone: utc))
        #expect(expand("{datetime}", locale: english).text == styled(.medium, .short, locale: english, timeZone: utc))
        #expect(expand("{iso}", timeZone: shanghai).text == "2026-03-04T05:06:07Z")
    }

    @Test func styleArgumentsMapToFormatterStyles() {
        let styles: [(String, DateFormatter.Style)] = [("short", .short), ("medium", .medium), ("long", .long), ("full", .full)]
        for (name, style) in styles {
            #expect(expand("{date:\(name)}", locale: english).text == styled(style, .none, locale: english, timeZone: utc))
            #expect(expand("{time:\(name)}", locale: english).text == styled(.none, style, locale: english, timeZone: utc))
            #expect(expand("{datetime:\(name)}", locale: english).text == styled(style, style, locale: english, timeZone: utc))
        }
        #expect(expand("{date:medium}", locale: english).text == expand("{date}", locale: english).text)
        #expect(expand("{time:short}", locale: english).text == expand("{time}", locale: english).text)
    }

    @Test func otherArgumentsAreDatePatterns() {
        #expect(expand("{date:yyyy-MM-dd}").text == "2026-03-04")
        #expect(expand("{time:HH:mm}").text == "05:06")
        #expect(expand("{time:HH:mm:ss}").text == "05:06:07")
        #expect(expand("{datetime:yyyy-MM-dd HH:mm}").text == "2026-03-04 05:06")
        #expect(expand("{date:EEEE d MMMM}").text == "Wednesday 4 March")
        #expect(expand("Due {date:yyyy/MM/dd} at {time:h:mm a}").text == "Due 2026/03/04 at 5:06 AM")
    }

    @Test func datesFollowTheTimeZone() {
        #expect(expand("{time:HH:mm}", timeZone: shanghai).text == "13:06")
        #expect(expand("{datetime:yyyy-MM-dd HH:mm}", timeZone: TimeZone(identifier: "America/Los_Angeles")!).text == "2026-03-03 21:06")
        #expect(expand("{time}", locale: english, timeZone: shanghai).text == styled(.none, .short, locale: english, timeZone: shanghai))
    }

    @Test func clipboardIsInsertedVerbatim() {
        #expect(expand("Re: {clipboard}", clipboard: "hello").text == "Re: hello")
        #expect(expand("Re: {clipboard}", clipboard: nil).text == "Re: ")
        #expect(expand("[{clipboard}] [{clipboard}]", clipboard: "a\nb").text == "[a\nb] [a\nb]")
        // Tokens inside the clipboard text stay as typed and do not move the caret.
        let pasted = expand("<{clipboard}>", clipboard: "{date} {cursor} {iso}")
        #expect(pasted.text == "<{date} {cursor} {iso}>")
        #expect(pasted.cursorOffset == 0)
    }

    @Test func cursorOffsetCountsCharactersAfterTheToken() {
        #expect(expand("{cursor}abc") == SnippetExpansion(text: "abc", cursorOffset: 3))
        #expect(expand("ab{cursor}cd") == SnippetExpansion(text: "abcd", cursorOffset: 2))
        #expect(expand("abc{cursor}") == SnippetExpansion(text: "abc", cursorOffset: 0))
        #expect(expand("abc") == SnippetExpansion(text: "abc", cursorOffset: 0))
        #expect(expand("{cursor}") == SnippetExpansion(text: "", cursorOffset: 0))
    }

    @Test func cursorOffsetCountsGraphemeClusters() {
        #expect(expand("你好{cursor}世界") == SnippetExpansion(text: "你好世界", cursorOffset: 2))
        #expect(expand("<b>{cursor}</b>") == SnippetExpansion(text: "<b></b>", cursorOffset: 4))
        // Skin tone and ZWJ family are one character each.
        #expect(expand("hi {cursor}👍🏽👨‍👩‍👧x") == SnippetExpansion(text: "hi 👍🏽👨‍👩‍👧x", cursorOffset: 3))
        #expect(expand("é{cursor}e\u{301}") == SnippetExpansion(text: "ée\u{301}", cursorOffset: 1))
    }

    @Test func newlinesCountAsOneCharacter() {
        #expect(expand("Dear {cursor},\n\nThanks\n") == SnippetExpansion(text: "Dear ,\n\nThanks\n", cursorOffset: 10))
        #expect(expand("a{cursor}\r\nb") == SnippetExpansion(text: "a\r\nb", cursorOffset: 2))
    }

    @Test func onlyTheFirstCursorCounts() {
        #expect(expand("a{cursor}b{cursor}c") == SnippetExpansion(text: "abc", cursorOffset: 2))
        #expect(expand("{cursor}{cursor}x{cursor}") == SnippetExpansion(text: "x", cursorOffset: 1))
    }

    @Test func cursorOffsetCountsExpandedTokens() {
        #expect(expand("x{cursor} {date:yyyy-MM-dd}") == SnippetExpansion(text: "x 2026-03-04", cursorOffset: 11))
        #expect(expand("{cursor}{clipboard}!", clipboard: "你好👋") == SnippetExpansion(text: "你好👋!", cursorOffset: 4))
    }

    @Test func unknownTokensAreLeftAsIs() {
        let untouched = [
            "{foo}", "{date:}", "{time:}", "{random:abc}", "{random}", "{Date}", "{ date }", "{cursor }",
            "{", "}", "{date", "a { b } c", "{}", "{{}}",
        ]
        for template in untouched {
            #expect(expand(template) == SnippetExpansion(text: template, cursorOffset: 0), "\(template)")
        }
        #expect(expand("{{date:yyyy}}").text == "{2026}")
        #expect(expand("{x{date:yyyy}").text == "{x2026")
        #expect(expand("{foo} {cursor}{bar}") == SnippetExpansion(text: "{foo} {bar}", cursorOffset: 5))
    }

    @Test func randomUUIDIsFreshEachTime() throws {
        let text = expand("{random:UUID} {random:uuid}").text
        let parts = text.split(separator: " ").map(String.init)
        #expect(parts.count == 2)
        let first = try #require(UUID(uuidString: parts[0]))
        let second = try #require(UUID(uuidString: parts[1]))
        #expect(first != second)
    }

    @Test func previewDropsOnlyTheCursor() {
        #expect(snippetPreviewText("Hi {cursor}, {date} {clipboard}") == "Hi , {date} {clipboard}")
        #expect(snippetPreviewText("a{cursor}b{cursor}") == "ab")
    }
}
