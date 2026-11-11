import Foundation

/// A snippet ready to paste: the text with its placeholders filled in, and how
/// far the caret has to move back from the end of that text afterwards.
public struct SnippetExpansion: Equatable, Sendable {
    public var text: String
    /// Characters (grapheme clusters) between the first `{cursor}` token and the
    /// end of `text`. Zero when the snippet has no `{cursor}` or it comes last.
    public var cursorOffset: Int

    public init(text: String, cursorOffset: Int = 0) {
        self.text = text
        self.cursorOffset = cursorOffset
    }
}

/// Fill in a snippet's placeholders.
///
/// - `{date}`, `{time}`, `{datetime}`: medium date, short time, or both.
/// - `{date:STYLE}`, `{time:STYLE}`, `{datetime:STYLE}`: `short`, `medium`,
///   `long` or `full`; any other argument is a Unicode date pattern such as
///   `yyyy-MM-dd` or `HH:mm`.
/// - `{iso}`: ISO 8601 in UTC.
/// - `{clipboard}`: `clipboard`, the plain-text clipboard read before Jfred
///   writes anything for the paste. Empty when there is none.
/// - `{random:UUID}`: a new UUID.
/// - `{cursor}`: removed; the first one sets `cursorOffset`. Later ones are dropped.
///
/// Unknown tokens stay as typed. Inserted values are never expanded again, so a
/// clipboard holding `{date}` pastes those characters.
public func expandSnippet(
    _ template: String,
    now: Date = Date(),
    clipboard: String? = nil,
    locale: Locale = .current,
    timeZone: TimeZone = .current
) -> SnippetExpansion {
    let resolver = SnippetTokenResolver(now: now, clipboard: clipboard, locale: locale, timeZone: timeZone)
    var beforeCursor = ""
    // Becomes non-nil at the first `{cursor}`; text from there on goes here.
    var afterCursor: String?
    func emit<S: StringProtocol>(_ piece: S) {
        if afterCursor != nil {
            afterCursor?.append(contentsOf: piece)
        } else {
            beforeCursor.append(contentsOf: piece)
        }
    }

    var rest = template[...]
    while let open = rest.firstIndex(of: "{") {
        emit(rest[..<open])
        rest = rest[open...]
        let bodyStart = rest.index(after: rest.startIndex)
        guard let close = rest[bodyStart...].firstIndex(of: "}") else { break }
        let body = rest[bodyStart..<close]
        if body == "cursor" {
            if afterCursor == nil { afterCursor = "" }
            rest = rest[rest.index(after: close)...]
        } else if let value = resolver.value(for: body) {
            emit(value)
            rest = rest[rest.index(after: close)...]
        } else {
            emit("{")
            rest = rest[bodyStart...]
        }
    }
    emit(rest)

    let tail = afterCursor ?? ""
    return SnippetExpansion(text: beforeCursor + tail, cursorOffset: tail.count)
}

/// Snippet text for display: placeholders stay readable, the caret marker goes.
public func snippetPreviewText(_ template: String) -> String {
    template.replacingOccurrences(of: "{cursor}", with: "")
}

private struct SnippetTokenResolver {
    let now: Date
    let clipboard: String?
    let locale: Locale
    let timeZone: TimeZone

    func value(for token: Substring) -> String? {
        switch token {
        case "date": return format(date: .medium, time: .none)
        case "time": return format(date: .none, time: .short)
        case "datetime": return format(date: .medium, time: .short)
        case "iso": return ISO8601DateFormatter().string(from: now)
        case "clipboard": return clipboard ?? ""
        default: break
        }
        guard let colon = token.firstIndex(of: ":") else { return nil }
        let name = token[..<colon]
        let argument = String(token[token.index(after: colon)...])
        switch name {
        case "date", "time", "datetime":
            guard !argument.isEmpty else { return nil }
            if let style = Self.style(named: argument) {
                return format(date: name == "time" ? .none : style, time: name == "date" ? .none : style)
            }
            let formatter = makeFormatter()
            formatter.dateFormat = argument
            return formatter.string(from: now)
        case "random":
            return argument.caseInsensitiveCompare("UUID") == .orderedSame ? UUID().uuidString : nil
        default:
            return nil
        }
    }

    private static func style(named name: String) -> DateFormatter.Style? {
        switch name {
        case "short": return .short
        case "medium": return .medium
        case "long": return .long
        case "full": return .full
        default: return nil
        }
    }

    private func format(date: DateFormatter.Style, time: DateFormatter.Style) -> String {
        let formatter = makeFormatter()
        formatter.dateStyle = date
        formatter.timeStyle = time
        return formatter.string(from: now)
    }

    private func makeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        return formatter
    }
}
