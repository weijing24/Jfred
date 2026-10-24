import Foundation

public func matchKeyword(_ keyword: String, in query: String, attached: Bool) -> String? {
    if let argument = argument(of: keyword, in: query) { return argument }
    guard attached, !keyword.isEmpty else { return nil }
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let foldedQuery = fold(trimmed)
    let foldedKey = fold(keyword)
    guard foldedQuery.count > foldedKey.count, foldedQuery.hasPrefix(foldedKey) else { return nil }
    let split = trimmed.index(trimmed.startIndex, offsetBy: keyword.count, limitedBy: trimmed.endIndex) ?? trimmed.endIndex
    return String(trimmed[split...])
}

public func bestKeywordMatch(_ keywords: [(keyword: String, attached: Bool)], in query: String) -> (keyword: String, argument: String)? {
    var best: (keyword: String, argument: String)?
    for entry in keywords {
        guard let argument = matchKeyword(entry.keyword, in: query, attached: entry.attached) else { continue }
        if let current = best, current.keyword.count >= entry.keyword.count { continue }
        best = (entry.keyword, argument)
    }
    return best
}

public enum WorkflowMatching {
    public static let devKeywords = [
        "json format", "encode", "decode", "uuid", "hash", "li", "qrcode", "time",
        "cc command", "cc lcfirst", "cc path", "cc camel", "cc title", "cc upper", "cc no",
        "cc constant", "cc sentence", "cc param", "cc dot", "cc snake", "cc ucfirst",
        "cc pascal", "cc lower", "cc hashtag", "cc swap",
        "nb decimal", "nb hexadecimal", "nb octal", "nb binary", "nb command",
        "dev",
    ]

    public static func summary(for builtin: String?) -> String? {
        switch builtin {
        case "dev":
            return "Keywords: encode, decode, uuid, hash, json format, cc snake, nb decimal, time, li, qrcode."
        case "profiles":
            return "Keyword cp. Extra letters filter the profile name."
        case "epoch":
            return "Keyword ts. epoch still works."
        case "unit":
            return "Keyword conv. unit still works."
        case "tabs":
            return "Keyword tabnhistory. tabs still works."
        case "windows":
            return "This workflow stays off. The hotkey is ⌥Tab."
        default:
            return nil
        }
    }

    public static func keywords(for workflow: Workflow) -> [(keyword: String, attached: Bool)] {
        var rows: [(String, Bool)] = []
        func add(_ keyword: String, _ attached: Bool) {
            let key = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            if rows.contains(where: { fold($0.0) == fold(key) }) { return }
            rows.append((key, attached))
        }
        switch workflow.builtin {
        case "dev":
            for keyword in devKeywords { add(keyword, false) }
        case "epoch":
            add("ts", false)
            add("epoch", false)
        case "unit":
            add("conv", false)
            add("unit", false)
        case "tabs":
            add("tabnhistory", false)
            add("tabs", false)
        case "profiles":
            add("cp", true)
            add("profile", false)
        case "windows":
            add("win", false)
        case "kill":
            add("kill", false)
        default:
            break
        }
        let attached = workflow.builtin == "profiles" && fold(workflow.keyword) == "cp"
        add(workflow.keyword, attached)
        return rows
    }

    public static func best(in workflows: [Workflow], query: String) -> (workflow: Workflow, keyword: String, argument: String)? {
        var winner: (Workflow, String, String, Int)?
        for workflow in workflows where workflow.enabled {
            for entry in keywords(for: workflow) {
                guard let argument = matchKeyword(entry.keyword, in: query, attached: entry.attached) else { continue }
                if let current = winner, current.3 >= entry.keyword.count { continue }
                winner = (workflow, entry.keyword, argument, entry.keyword.count)
            }
        }
        if let winner { return (winner.0, winner.1, winner.2) }
        return nil
    }
}

public enum ScriptJSON {
    public struct Item: Equatable, Sendable {
        public var title: String
        public var subtitle: String
        public var arg: String
        public var valid: Bool

        public init(title: String, subtitle: String, arg: String, valid: Bool) {
            self.title = title
            self.subtitle = subtitle
            self.arg = arg
            self.valid = valid
        }
    }

    public static func items(in text: String) -> [Item]? {
        var found: [Item]?
        for data in objects(in: text) {
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rows = object["items"] as? [[String: Any]] else { continue }
            found = rows.map { row in
                Item(
                    title: string(row["title"]) ?? "",
                    subtitle: string(row["subtitle"]) ?? "",
                    arg: string(row["arg"]) ?? "",
                    valid: (row["valid"] as? Bool) ?? true
                )
            }
        }
        return found
    }

    private static func string(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private static func objects(in text: String) -> [Data] {
        let chars = Array(text)
        var results: [Data] = []
        var index = 0
        while index < chars.count {
            if chars[index] == "{", let end = balancedEnd(chars, from: index) {
                let slice = String(chars[index...end])
                if let data = slice.data(using: .utf8) { results.append(data) }
                index = end + 1
                continue
            }
            index += 1
        }
        return results
    }

    private static func balancedEnd(_ chars: [Character], from start: Int) -> Int? {
        var depth = 0
        var inString = false
        var escape = false
        for index in start..<chars.count {
            let character = chars[index]
            if inString {
                if escape {
                    escape = false
                    continue
                }
                if character == "\\" {
                    escape = true
                    continue
                }
                if character == "\"" { inString = false }
                continue
            }
            if character == "\"" {
                inString = true
                continue
            }
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { return index }
            }
        }
        return nil
    }
}
