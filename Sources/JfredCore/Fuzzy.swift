import Foundation

public func fold(_ text: String) -> String {
    text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
}

/// Lower is better: exact, prefix, word prefix, substring, then fuzzy.
public struct FieldMatch: Equatable, Sendable {
    public var tier: Int
    public var score: Double

    public init(tier: Int, score: Double) {
        self.tier = tier
        self.score = score
    }
}

public func fieldMatch(query: String, target: String) -> FieldMatch? {
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

public func bestFieldMatch(query: String, fields: [String]) -> FieldMatch? {
    fields.compactMap { fieldMatch(query: query, target: $0) }.min { lhs, rhs in
        if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
        return lhs.score > rhs.score
    }
}

public func fuzzyScore(query: String, target: String) -> Double? {
    fieldMatch(query: query, target: target)?.score
}

public func bestFuzzyScore(query: String, fields: [String]) -> Double? {
    bestFieldMatch(query: query, fields: fields)?.score
}
