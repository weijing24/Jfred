import Foundation

public func fold(_ text: String) -> String {
    text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
}

public func fuzzyScore(query: String, target: String) -> Double? {
    let q = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
    let t = fold(target)
    if q.isEmpty || t.isEmpty { return nil }
    if t == q { return 1 }
    var score = 0.0
    if t.hasPrefix(q) {
        score = 0.97
    }
    let words = t.split { !$0.isLetter && !$0.isNumber }
    if words.contains(where: { $0.hasPrefix(q) }) {
        score = max(score, 0.93)
    }
    if t.contains(q) {
        score = max(score, 0.84)
    }
    var index = t.startIndex
    var streak = 0
    var raw = 0.0
    for character in q {
        guard let found = t[index...].firstIndex(of: character) else {
            return score > 0 ? score - Double(t.count) * 0.001 : nil
        }
        let distance = t.distance(from: index, to: found)
        let atBoundary = found == t.startIndex || !t[t.index(before: found)].isLetter
        streak = distance == 0 ? streak + 1 : 1
        raw += 1 + Double(streak) * 0.18 + (atBoundary ? 0.25 : 0) - Double(distance) * 0.03
        index = t.index(after: found)
    }
    let subsequence = min(0.9, raw / (Double(q.count) * 2.1))
    score = max(score, subsequence)
    if score <= 0 { return nil }
    score -= Double(t.count) * 0.0015
    return score
}

public func bestFuzzyScore(query: String, fields: [String]) -> Double? {
    fields.compactMap { fuzzyScore(query: query, target: $0) }.max()
}
