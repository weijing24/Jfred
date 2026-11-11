import Foundation

/// A file lookup the launcher hands to Spotlight: a file name search (quick
/// search, `open`, `find`), a file contents search (`in`) or a tag search
/// (`tags`).
public struct FileQuery: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case name
        case content
        case tags
    }

    public var kind: Kind
    /// The search text as typed after the prefix or keyword.
    public var text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }

    /// Whitespace-separated terms. Every term must match.
    public var terms: [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Spotlight results read per name query. Spotlight evaluates the whole
    /// predicate whatever this is; reading a result's names costs well under a
    /// microsecond, so a large pool costs little and lets the best matches win.
    public static let nameCandidateLimit = 2000
    /// Spotlight results read for a name query of single characters. A cold
    /// one-letter query can take several seconds to gather 2000 results; asking
    /// for fewer often lets Spotlight stop after tens of milliseconds.
    public static let singleCharacterCandidateLimit = 100
    /// Spotlight results read per contents or tags query.
    public static let otherCandidateLimit = 1000

    /// A name query whose shortest term is shorter than this waits
    /// `shortQueryDelay` before it reaches Spotlight.
    public static let shortTermLength = 3
    /// Long enough to span the gap between two typed keys, so a short prefix
    /// typed on the way to a longer one never starts a Spotlight query.
    public static let shortQueryDelay: TimeInterval = 0.22

    /// The terms Spotlight is asked for.
    var spotlightTerms: [String] {
        terms.flatMap(SpotlightPredicate.spotlightTerms)
    }

    /// How many Spotlight results to read.
    public var candidateLimit: Int {
        switch kind {
        case .name:
            let terms = spotlightTerms
            if !terms.isEmpty, terms.allSatisfy({ $0.count == 1 }) {
                return Self.singleCharacterCandidateLimit
            }
            return Self.nameCandidateLimit
        case .content, .tags:
            return Self.otherCandidateLimit
        }
    }

    /// Seconds to wait before starting the Spotlight query. A short name prefix
    /// matches a large part of the disk and, until Spotlight has cached it,
    /// takes one to several seconds, so it waits to see whether the user keeps
    /// typing. Everything else starts at once.
    public var launchDelay: TimeInterval {
        guard kind == .name else { return 0 }
        let terms = spotlightTerms
        guard let shortest = terms.map(\.count).min() else { return 0 }
        return shortest < Self.shortTermLength ? Self.shortQueryDelay : 0
    }
}

/// A file Spotlight found, after path exclusion.
public struct FileHit: Sendable, Equatable {
    public var path: String
    /// Finder's display name, which may be localized or hide the extension.
    public var name: String
    /// `kMDItemLastUsedDate`, when Spotlight has one.
    public var lastUsed: Date?

    public init(path: String, name: String, lastUsed: Date? = nil) {
        self.path = path
        self.name = name
        self.lastUsed = lastUsed
    }
}

/// A Spotlight result before its path is resolved. Reading a path costs far
/// more than reading names, so candidates are ranked first and only the best
/// ones get a path.
public struct FileCandidate: Sendable, Equatable {
    /// `kMDItemDisplayName`.
    public var name: String
    /// `kMDItemFSName`.
    public var fileName: String
    public var lastUsed: Date?

    public init(name: String, fileName: String, lastUsed: Date? = nil) {
        self.name = name
        self.fileName = fileName
        self.lastUsed = lastUsed
    }
}

/// Spotlight query strings for a `FileQuery`.
public enum SpotlightPredicate {
    /// Escapes a term for a double-quoted value. A backslash makes `*` and `?`
    /// literal instead of wildcards, and keeps `"` and `\` from ending or
    /// escaping the value.
    public static func escape(_ term: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(term.count)
        for character in term {
            switch character {
            case "\\", "\"", "*", "?":
                escaped.append("\\")
                escaped.append(character)
            default:
                escaped.append(character)
            }
        }
        return escaped
    }

    /// Every term must match. Names and contents match at the start of a word
    /// (`w`); a tag matches when one of the file's tags starts with the term.
    /// All matching ignores case (`c`) and diacritics (`d`). Nil when the query
    /// has no terms.
    public static func make(for query: FileQuery) -> String? {
        let terms = query.terms.flatMap(spotlightTerms)
        guard !terms.isEmpty else { return nil }
        let attribute: String
        let modifiers: String
        switch query.kind {
        case .name:
            // kMDItemFSName is several times faster to query than kMDItemDisplayName.
            attribute = "kMDItemFSName"
            modifiers = "cdw"
        case .content:
            attribute = "kMDItemTextContent"
            modifiers = "cdw"
        case .tags:
            attribute = "kMDItemUserTags"
            modifiers = "cd"
        }
        return terms
            .map { "\(attribute) == \"\(escape($0))*\"\(modifiers)" }
            .joined(separator: " && ")
    }

    /// A query value with a letter before an apostrophe matches nothing, even
    /// escaped: `"O'Brien"` misses a file named O'Brien. Spotlight's word index
    /// splits names there, so look for the pieces instead. Pieces of one
    /// character would make slow, broad queries and are dropped unless nothing
    /// else is left. The launcher still matches the whole query against each name.
    static func spotlightTerms(_ term: String) -> [String] {
        let pieces = term.split { $0 == "'" || $0 == "\u{2019}" || $0 == "\u{2018}" }.map(String.init)
        guard pieces.count > 1 else { return pieces }
        let long = pieces.filter { $0.count > 1 }
        if !long.isEmpty { return long }
        return pieces.max { $0.count < $1.count }.map { [$0] } ?? []
    }
}

/// Paths the file search leaves out even though Spotlight indexes them.
public struct FileScopeFilter: Sendable {
    /// Build output, dependency caches and version control data. The Go module
    /// cache is a `mod` folder inside `pkg`, checked separately.
    public static let skippedFolders: Set<String> = ["node_modules", ".git", ".build", "DerivedData", "Pods"]
    /// Packages whose contents are not separate results.
    public static let packageExtensions: Set<String> = ["app", "prefpane", "photoslibrary", "musiclibrary", "tvlibrary", "aplibrary"]

    private struct Root: Sendable {
        /// Lowercased root followed by "/", or "/" for the file system root.
        let prefix: String
        let depth: Int
    }

    /// Scope roots, deepest first.
    private let roots: [Root]

    public init(roots: [String]) {
        var seen = Set<String>()
        var prepared: [Root] = []
        for root in roots {
            var path = root
            while path.count > 1, path.hasSuffix("/") { path.removeLast() }
            guard path.hasPrefix("/") else { continue }
            let folded = path.lowercased()
            guard seen.insert(folded).inserted else { continue }
            let depth = path.split(separator: "/").count
            prepared.append(Root(prefix: depth == 0 ? "/" : folded + "/", depth: depth))
        }
        self.roots = prepared.sorted { $0.depth > $1.depth }
    }

    /// True for a path inside a skipped folder or the Go module cache
    /// (`$GOPATH/pkg/mod`), under a hidden component, or inside a package. Only
    /// the part below the deepest scope root counts, so a scope root such as
    /// `/Applications/Xcode.app/Contents/Applications` still returns the apps
    /// inside it.
    public func excludes(_ path: String) -> Bool {
        let components = relativeComponents(path)
        var previous: Substring = ""
        for (index, component) in components.enumerated() {
            if component.hasPrefix(".") { return true }
            if Self.skippedFolders.contains(String(component)) { return true }
            if previous == "pkg", component == "mod" { return true }
            if index < components.count - 1 {
                let ext = (component as NSString).pathExtension.lowercased()
                if Self.packageExtensions.contains(ext) { return true }
            }
            previous = component
        }
        return false
    }

    /// Path components below the deepest root that contains the path. Roots
    /// compare case-insensitively, as on the default macOS file system.
    private func relativeComponents(_ path: String) -> ArraySlice<Substring> {
        let parts = path.split(separator: "/")
        let folded = path.lowercased() + "/"
        for root in roots where root.depth <= parts.count && folded.hasPrefix(root.prefix) {
            return parts.dropFirst(root.depth)
        }
        return parts[...]
    }
}

public enum FileRanking {
    /// The most a recently used file adds to its score. Below the gap between
    /// match tiers, so recency only reorders files that match equally well.
    public static let recencyWeight = 0.012
    /// The boost halves every two weeks.
    public static let recencyHalfLife: TimeInterval = 14 * 24 * 3600

    public static func recencyBoost(_ lastUsed: Date?, now: Date) -> Double {
        guard let lastUsed else { return 0 }
        let age = max(0, now.timeIntervalSince(lastUsed))
        return recencyWeight * pow(0.5, age / recencyHalfLife)
    }

    /// Candidate indices, most recently used first; unused candidates keep
    /// Spotlight's order. Used for contents and tag searches, which have no
    /// name match to rank by.
    public static func recentFirst(_ candidates: [FileCandidate]) -> [Int] {
        candidates.indices.sorted { lhs, rhs in
            let left = candidates[lhs].lastUsed ?? .distantPast
            let right = candidates[rhs].lastUsed ?? .distantPast
            if left != right { return left > right }
            return lhs < rhs
        }
    }
}
