import Foundation

public enum WorkflowScriptLanguage: String, Codable, Sendable {
    case bash
    case php
    case ruby
    case python
    case perl
    case zsh
    case osascript
    case swift
    case external
}

public enum WorkflowArgumentMode: String, Codable, Sendable {
    case argv
    case query
}

public struct WorkflowScriptRequest: Sendable, Equatable {
    public var workflowID: UUID
    public var objectID: UUID
    public var bundleID: String
    public var workflowName: String
    public var workflowVersion: String
    public var keyword: String
    public var language: WorkflowScriptLanguage
    public var source: String
    public var sourceFile: String
    public var argumentMode: WorkflowArgumentMode
    public var escaping: Int
    public var query: String
    public var arguments: [String]
    public var variables: [String: String]
    public var directory: URL
    public var environment: [String: String]

    public init(
        workflowID: UUID,
        objectID: UUID,
        bundleID: String,
        workflowName: String,
        workflowVersion: String,
        keyword: String,
        language: WorkflowScriptLanguage,
        source: String,
        sourceFile: String,
        argumentMode: WorkflowArgumentMode,
        escaping: Int,
        query: String,
        arguments: [String],
        variables: [String: String],
        directory: URL,
        environment: [String: String]
    ) {
        self.workflowID = workflowID
        self.objectID = objectID
        self.bundleID = bundleID
        self.workflowName = workflowName
        self.workflowVersion = workflowVersion
        self.keyword = keyword
        self.language = language
        self.source = source
        self.sourceFile = sourceFile
        self.argumentMode = argumentMode
        self.escaping = escaping
        self.query = query
        self.arguments = arguments
        self.variables = variables
        self.directory = directory
        self.environment = environment
    }
}

public struct WorkflowScriptOutput: Sendable, Equatable {
    public var stdout: String
    public var stderr: String
    public var status: Int32
    public var error: String?

    public init(stdout: String = "", stderr: String = "", status: Int32 = 0, error: String? = nil) {
        self.stdout = stdout
        self.stderr = stderr
        self.status = status
        self.error = error
    }

    public var isSuccess: Bool { error == nil && status == 0 }
}

public protocol WorkflowScriptRunning: Sendable {
    func run(_ request: WorkflowScriptRequest) async -> WorkflowScriptOutput
}

public struct WorkflowItemMod: Codable, Equatable, Sendable {
    public var valid: Bool?
    public var arguments: [String]?
    public var subtitle: String?
    public var variables: [String: String]?
    public var iconPath: String?

    public init(valid: Bool? = nil, arguments: [String]? = nil, subtitle: String? = nil, variables: [String: String]? = nil, iconPath: String? = nil) {
        self.valid = valid
        self.arguments = arguments
        self.subtitle = subtitle
        self.variables = variables
        self.iconPath = iconPath
    }
}

public struct WorkflowItem: Codable, Equatable, Sendable {
    public var uid: String
    public var title: String
    public var subtitle: String
    public var arguments: [String]
    public var valid: Bool
    public var autocomplete: String
    public var match: String
    public var iconPath: String
    public var iconType: String
    public var type: String
    public var quickLookURL: String
    public var variables: [String: String]
    public var mods: [String: WorkflowItemMod]

    public init(
        uid: String = "",
        title: String = "",
        subtitle: String = "",
        arguments: [String] = [],
        valid: Bool = true,
        autocomplete: String = "",
        match: String = "",
        iconPath: String = "",
        iconType: String = "",
        type: String = "default",
        quickLookURL: String = "",
        variables: [String: String] = [:],
        mods: [String: WorkflowItemMod] = [:]
    ) {
        self.uid = uid
        self.title = title
        self.subtitle = subtitle
        self.arguments = arguments
        self.valid = valid
        self.autocomplete = autocomplete
        self.match = match
        self.iconPath = iconPath
        self.iconType = iconType
        self.type = type
        self.quickLookURL = quickLookURL
        self.variables = variables
        self.mods = mods
    }

    public var argument: String { arguments.first ?? "" }

    public func applying(modifier: WorkflowModifier) -> WorkflowItem {
        guard let key = modifier.itemKey, let mod = mods[key] else { return self }
        var copy = self
        if let valid = mod.valid { copy.valid = valid }
        if let arguments = mod.arguments { copy.arguments = arguments }
        if let subtitle = mod.subtitle { copy.subtitle = subtitle }
        if let variables = mod.variables { copy.variables = variables }
        if let iconPath = mod.iconPath { copy.iconPath = iconPath }
        return copy
    }
}

public struct WorkflowScriptFilterResult: Sendable, Equatable {
    public var items: [WorkflowItem]
    public var variables: [String: String]
    public var rerun: Double?

    public init(items: [WorkflowItem], variables: [String: String] = [:], rerun: Double? = nil) {
        self.items = items
        self.variables = variables
        self.rerun = rerun
    }
}

public struct WorkflowModifier: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = WorkflowModifier(rawValue: 1 << 20)
    public static let option = WorkflowModifier(rawValue: 1 << 19)
    public static let control = WorkflowModifier(rawValue: 1 << 18)
    public static let shift = WorkflowModifier(rawValue: 1 << 17)
    public static let none: WorkflowModifier = []

    public init(forced: String) {
        switch forced {
        case "command": self = .command
        case "option": self = .option
        case "control": self = .control
        case "shift": self = .shift
        default: self = .none
        }
    }

    public var itemKey: String? {
        if rawValue == WorkflowModifier.command.rawValue { return "cmd" }
        if rawValue == WorkflowModifier.option.rawValue { return "alt" }
        if rawValue == WorkflowModifier.control.rawValue { return "ctrl" }
        if rawValue == WorkflowModifier.shift.rawValue { return "shift" }
        return nil
    }
}

public struct WorkflowInvocation: Sendable, Equatable {
    public var workflowID: UUID
    public var inputID: UUID
    public var keyword: String
    public var argument: String
    public var variables: [String: String]

    public init(workflowID: UUID, inputID: UUID, keyword: String, argument: String, variables: [String: String] = [:]) {
        self.workflowID = workflowID
        self.inputID = inputID
        self.keyword = keyword
        self.argument = argument
        self.variables = variables
    }
}

public struct WorkflowRunPayload: Codable, Equatable, Sendable {
    public var workflowID: UUID
    public var inputID: UUID
    public var keyword: String
    public var argument: String
    public var variables: [String: String]
    public var item: WorkflowItem?

    public init(workflowID: UUID, inputID: UUID, keyword: String, argument: String, variables: [String: String] = [:], item: WorkflowItem? = nil) {
        self.workflowID = workflowID
        self.inputID = inputID
        self.keyword = keyword
        self.argument = argument
        self.variables = variables
        self.item = item
    }

    public init(invocation: WorkflowInvocation, item: WorkflowItem? = nil) {
        self.init(
            workflowID: invocation.workflowID,
            inputID: invocation.inputID,
            keyword: invocation.keyword,
            argument: invocation.argument,
            variables: invocation.variables,
            item: item
        )
    }

    public var json: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(_ text: String) -> WorkflowRunPayload? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WorkflowRunPayload.self, from: data)
    }
}

public struct WorkflowMatch: Sendable {
    public var workflow: Workflow
    public var input: WorkflowObject
    public var invocation: WorkflowInvocation

    public init(workflow: Workflow, input: WorkflowObject, invocation: WorkflowInvocation) {
        self.workflow = workflow
        self.input = input
        self.invocation = invocation
    }
}

public struct WorkflowLogEntry: Sendable, Equatable {
    public var objectID: UUID
    public var title: String
    public var detail: String
    public var output: String
    public var isError: Bool

    public init(objectID: UUID, title: String, detail: String = "", output: String = "", isError: Bool = false) {
        self.objectID = objectID
        self.title = title
        self.detail = detail
        self.output = output
        self.isError = isError
    }
}

public enum WorkflowEffect: Equatable, Sendable {
    case openURL(String)
    case openFile(String)
    case revealFile(String)
    case copy(String)
    case largeType(String)
    case notification(title: String, text: String)
    case playSound(String)
    case speak(String)
    case writeFile(path: String, text: String)
    case terminal(String)
    case unsupported(String)
}

public struct WorkflowFrame: Sendable, Equatable {
    public var objectID: UUID
    public var arguments: [String]
    public var variables: [String: String]
    public var modifier: WorkflowModifier

    public init(objectID: UUID, arguments: [String], variables: [String: String], modifier: WorkflowModifier) {
        self.objectID = objectID
        self.arguments = arguments
        self.variables = variables
        self.modifier = modifier
    }

    public var query: String { arguments.joined(separator: " ") }
}

public struct WorkflowRunState: Sendable {
    public var pending: [WorkflowFrame]
    public var logs: [WorkflowLogEntry]
    public var effects: [WorkflowEffect]
    public var processed: Int
    public var limit: Int

    public init(pending: [WorkflowFrame], logs: [WorkflowLogEntry] = [], effects: [WorkflowEffect] = [], processed: Int = 0, limit: Int = 256) {
        self.pending = pending
        self.logs = logs
        self.effects = effects
        self.processed = processed
        self.limit = limit
    }

    public var finished: Bool { pending.isEmpty || processed >= limit }
}

public struct WorkflowEngine: Sendable {
    public let workflow: Workflow
    public let runner: any WorkflowScriptRunning
    public let rootURL: URL
    public let environment: [String: String]

    public init(workflow: Workflow, runner: any WorkflowScriptRunning, environment: [String: String] = [:]) {
        self.workflow = workflow
        self.runner = runner
        self.rootURL = workflow.rootPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        self.environment = environment
    }

    public static func match(in workflows: [Workflow], query: String, disabledBuiltins: Set<String> = []) -> WorkflowMatch? {
        var winner: (Workflow, WorkflowObject, String, String, Int)?
        for workflow in workflows where workflow.enabled {
            if let builtin = workflow.builtin, disabledBuiltins.contains(builtin) { continue }
            for input in workflow.searchInputs {
                let keyword = input.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !keyword.isEmpty else { continue }
                guard let argument = matchKeyword(keyword, in: query, attached: !input.withSpace) else { continue }
                if let current = winner, current.4 >= keyword.count { continue }
                winner = (workflow, input, keyword, argument, keyword.count)
            }
        }
        guard let winner else { return nil }
        let variables = winner.0.variables.merging(["alfred_workflow_keyword": winner.2]) { _, new in new }
        let invocation = WorkflowInvocation(
            workflowID: winner.0.id,
            inputID: winner.1.id,
            keyword: winner.2,
            argument: winner.3,
            variables: variables
        )
        return WorkflowMatch(workflow: winner.0, input: winner.1, invocation: invocation)
    }

    /// Returns items for a Script Filter or List Filter input. A plain Keyword
    /// returns nil; the caller should present the workflow itself as one row.
    public func results(for invocation: WorkflowInvocation) async -> WorkflowScriptFilterResult? {
        guard let input = workflow.object(id: invocation.inputID) else { return nil }
        switch input.kind {
        case .listFilter:
            return listFilterResult(input, query: invocation.argument)
        case .scriptFilter:
            return await scriptFilterResult(input, invocation: invocation)
        default:
            return nil
        }
    }

    public func initialState(invocation: WorkflowInvocation, item: WorkflowItem? = nil, modifier: WorkflowModifier = .none) -> WorkflowRunState {
        var variables = invocation.variables
        var arguments = item?.arguments ?? [invocation.argument]
        if let item {
            let applied = item.applying(modifier: modifier)
            variables.merge(applied.variables) { _, new in new }
            if !applied.arguments.isEmpty { arguments = applied.arguments }
            if let input = workflow.object(id: invocation.inputID) {
                // A selected result starts after the Script Filter object.
                let outgoing = outgoingFrames(from: input, arguments: arguments, variables: variables, modifier: modifier)
                return WorkflowRunState(pending: outgoing)
            }
        }
        return WorkflowRunState(pending: [
            WorkflowFrame(objectID: invocation.inputID, arguments: arguments, variables: variables, modifier: modifier)
        ])
    }

    public func run(invocation: WorkflowInvocation, item: WorkflowItem? = nil, modifier: WorkflowModifier = .none) async -> WorkflowRunState {
        var state = initialState(invocation: invocation, item: item, modifier: modifier)
        while !state.finished {
            let didStep = await step(&state)
            if !didStep { break }
        }
        return state
    }

    @discardableResult
    public func step(_ state: inout WorkflowRunState) async -> Bool {
        guard !state.pending.isEmpty else { return false }
        guard state.processed < state.limit else {
            state.pending = []
            state.logs.append(WorkflowLogEntry(objectID: UUID(), title: "Workflow", detail: "Stopped after \(state.limit) objects to prevent a cycle.", isError: true))
            return false
        }
        let frame = state.pending.removeFirst()
        state.processed += 1
        guard let object = workflow.object(id: frame.objectID) else {
            state.logs.append(WorkflowLogEntry(objectID: frame.objectID, title: "Missing object", detail: frame.objectID.uuidString, isError: true))
            return true
        }
        let result = await process(object, frame: frame)
        state.logs.append(result.log)
        state.effects.append(contentsOf: result.effects)
        state.pending.append(contentsOf: result.next)
        return true
    }

    public func scriptFilterResult(_ input: WorkflowObject, invocation: WorkflowInvocation) async -> WorkflowScriptFilterResult? {
        let request = scriptRequest(for: input, arguments: [invocation.argument], variables: invocation.variables, keyword: invocation.keyword)
        let output = await runner.run(request)
        // Some legacy workflows exit non-zero after printing a valid result
        // document (for example Alfred-Workflow's version check). Prefer the
        // stdout document when it contains items.
        if !output.isSuccess, output.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return WorkflowScriptFilterResult(items: [], variables: [:])
        }
        var result = WorkflowScriptFilterParser.parse(output.stdout)
        if input.filtersResults, !invocation.argument.isEmpty {
            result.items = WorkflowScriptFilterParser.filter(result.items, query: invocation.argument, mode: input.filterMatchMode)
        }
        return result
    }

    public func listFilterResult(_ input: WorkflowObject, query: String) -> WorkflowScriptFilterResult? {
        let rows = WorkflowScriptFilterParser.parseListItems(input.config[string: "items"])
        let filtered: [WorkflowItem]
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            filtered = rows
        } else {
            filtered = WorkflowScriptFilterParser.filter(rows, query: query, mode: 2)
        }
        return WorkflowScriptFilterResult(items: filtered)
    }

    public func scriptRequest(for object: WorkflowObject, arguments: [String], variables: [String: String], keyword: String) -> WorkflowScriptRequest {
        let query = arguments.joined(separator: " ")
        let argumentMode: WorkflowArgumentMode = object.scriptArgumentType == 1 ? .argv : .query
        let source: String
        if argumentMode == .query {
            source = WorkflowTemplate.expand(object.script, query: query, variables: variables, escaping: object.escaping, rootURL: rootURL)
        } else {
            source = WorkflowTemplate.expand(object.script, query: query, variables: variables, escaping: 0, rootURL: rootURL)
        }
        var mergedEnvironment = environment
        mergedEnvironment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (mergedEnvironment["PATH"] ?? "/usr/bin:/bin")
        for (key, value) in workflow.variables { mergedEnvironment[key] = value }
        for (key, value) in variables { mergedEnvironment[key] = value }
        mergedEnvironment["alfred_workflow_bundleid"] = workflow.bundleID
        mergedEnvironment["alfred_workflow_name"] = workflow.name
        mergedEnvironment["alfred_workflow_version"] = workflow.version
        mergedEnvironment["alfred_workflow_uid"] = workflow.id.uuidString
        mergedEnvironment["alfred_workflow_keyword"] = keyword
        mergedEnvironment["alfred_version"] = "5.8.1"
        mergedEnvironment["alfred_version_build"] = "2349"
        mergedEnvironment["alfred_workflow_cache"] = cacheDirectory.path
        mergedEnvironment["alfred_workflow_data"] = dataDirectory.path
        mergedEnvironment["alfred_workflow_root"] = rootURL.path
        return WorkflowScriptRequest(
            workflowID: workflow.id,
            objectID: object.id,
            bundleID: workflow.bundleID,
            workflowName: workflow.name,
            workflowVersion: workflow.version,
            keyword: keyword,
            language: WorkflowEngine.language(for: object),
            source: source,
            sourceFile: object.scriptFile,
            argumentMode: argumentMode,
            escaping: object.escaping,
            query: query,
            arguments: argumentMode == .argv ? arguments : [],
            variables: variables,
            directory: rootURL,
            environment: mergedEnvironment
        )
    }

    public var cacheDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/JfredLocal/Workflows/\(workflow.bundleID.isEmpty ? workflow.id.uuidString : workflow.bundleID)", isDirectory: true)
    }

    public var dataDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/JfredLocal/Workflow Data/\(workflow.bundleID.isEmpty ? workflow.id.uuidString : workflow.bundleID)", isDirectory: true)
    }

    public static func language(for object: WorkflowObject) -> WorkflowScriptLanguage {
        if !object.scriptFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .external }
        if object.script.hasPrefix("#!") { return .external }
        switch object.scriptType {
        case 0: return .bash
        case 1: return .php
        case 2: return .ruby
        case 3: return .python
        case 4: return .perl
        case 5: return .zsh
        case 6: return .osascript
        case 7: return .swift
        default: return .zsh
        }
    }

    private struct Processed {
        var log: WorkflowLogEntry
        var effects: [WorkflowEffect]
        var next: [WorkflowFrame]
    }

    private func process(_ object: WorkflowObject, frame: WorkflowFrame) async -> Processed {
        let query = frame.query
        let variables = frame.variables
        func expanded(_ value: String, escaping: Int = 0) -> String {
            WorkflowTemplate.expand(value, query: query, variables: variables, escaping: escaping, rootURL: rootURL)
        }
        func log(_ detail: String, output: String = "", error: Bool = false) -> WorkflowLogEntry {
            WorkflowLogEntry(objectID: object.id, title: object.title, detail: detail, output: output, isError: error)
        }
        func next(_ arguments: [String] = frame.arguments, variables: [String: String]? = nil, branch: String? = nil) -> [WorkflowFrame] {
            let frames = outgoingFrames(from: object, arguments: arguments, variables: variables ?? frame.variables, modifier: frame.modifier, branch: branch)
            return frames
        }

        switch object.kind {
        case .keyword, .hotkey, .universalAction, .externalTriggerInput, .junction, .scriptFilter, .listFilter:
            return Processed(log: log("Passed “\(query)” through"), effects: [], next: next())

        case .runScript, .appleScript:
            let request = scriptRequest(for: object, arguments: frame.arguments, variables: variables, keyword: workflow.keyword)
            let output = await runner.run(request)
            let stdout = output.stdout.trimmingCharacters(in: .newlines)
            let detail = output.isSuccess ? "Ran \(object.title)" : "Script failed (\(output.status))"
            let entry = log(detail, output: output.isSuccess ? stdout : output.stderr, error: !output.isSuccess)
            return Processed(log: entry, effects: [], next: next(stdout.isEmpty ? frame.arguments : [stdout]))

        case .openURL:
            let url = expanded(object.config[string: "url"])
            return Processed(log: log(url), effects: [.openURL(url)], next: next())

        case .openFile:
            let path = expanded(object.config[string: "path"])
            return Processed(log: log(path), effects: [.openFile(path)], next: next())

        case .revealFile:
            let path = expanded(object.config[string: "path"])
            return Processed(log: log(path), effects: [.revealFile(path)], next: next())

        case .clipboard:
            let text = expanded(object.config[string: "clipboardtext"].isEmpty ? object.config[string: "text"] : object.config[string: "clipboardtext"])
            return Processed(log: log(text), effects: [.copy(text)], next: next())

        case .largeType:
            let text = expanded(object.config[string: "text"])
            return Processed(log: log(text), effects: [.largeType(text)], next: next())

        case .notification:
            let title = expanded(object.config[string: "title"])
            let configuredText = object.config[string: "text"]
            let text = expanded(configuredText.isEmpty ? query : configuredText)
            return Processed(log: log(text), effects: [.notification(title: title, text: text)], next: next())

        case .playSound:
            let path = expanded(object.config[string: "path"])
            return Processed(log: log(path), effects: [.playSound(path)], next: next())

        case .speak:
            let text = expanded(object.config[string: "text"])
            return Processed(log: log(text), effects: [.speak(text)], next: next())

        case .writeFile:
            let path = expanded(object.config[string: "path"])
            let text = expanded(object.config[string: "text"].isEmpty ? object.config[string: "content"] : object.config[string: "text"])
            return Processed(log: log(path), effects: [.writeFile(path: path, text: text)], next: next())

        case .terminal:
            let command = expanded(object.config[string: "command"].isEmpty ? object.script : object.config[string: "command"])
            return Processed(log: log(command), effects: [.terminal(command)], next: next())

        case .argument:
            var outputVariables = frame.variables
            for (key, value) in object.config.strings("variables") {
                outputVariables[key] = expanded(value)
            }
            let passthrough = object.config["passthroughargument"]?.boolValue ?? false
            let argument = passthrough ? frame.arguments : [expanded(object.config[string: "argument"])]
            let detail = argument.joined(separator: " ")
            return Processed(log: log(detail), effects: [], next: next(argument, variables: outputVariables))

        case .conditional:
            let branch = conditionalBranch(object, query: query, variables: variables, rootURL: rootURL)
            let label = branch.flatMap { conditionLabel(in: object, uid: $0) } ?? "otherwise"
            return Processed(log: log(label), effects: [], next: next(branch: branch))

        case .filter:
            let input = expanded(object.config[string: "inputstring"])
            let match = expanded(object.config[string: "matchstring"])
            let mode = object.config[integer: "matchmode"]
            let caseSensitive = object.config["matchcasesensitive"]?.boolValue ?? false
            let passed = WorkflowTemplate.filterMatches(input, pattern: match, mode: mode, caseSensitive: caseSensitive)
            return Processed(log: log(passed ? "Passed filter" : "Stopped by filter"), effects: [], next: passed ? next() : [])

        case .delay:
            let seconds = max(0, min(30, object.config["seconds"]?.doubleValue ?? object.config["delay"]?.doubleValue ?? 0.3))
            try? await Task.sleep(for: .seconds(seconds))
            return Processed(log: log("Waited \(seconds)s"), effects: [], next: next())

        case .debug:
            let text = expanded(object.config[string: "text"].isEmpty ? query : object.config[string: "text"])
            return Processed(log: log(text), effects: [.notification(title: "Workflow Debug", text: text)], next: next())

        case .externalTrigger:
            let trigger = expanded(object.config[string: "triggerid"])
            return Processed(log: log("External trigger \(trigger) is not connected in Jfred", error: true), effects: [], next: next())

        case .automationTask:
            let task = object.config[string: "taskuid"]
            return Processed(log: log("Alfred Automation Task not supported: \(task)", error: true), effects: [.unsupported("Automation Task: \(task)")], next: next())

        case .textView:
            let text = readTextFile(object.config[string: "inputfile"]) ?? object.config[string: "text"]
            return Processed(log: log(text), effects: [.largeType(text)], next: next())

        case .userInterface, .unknown:
            return Processed(log: log("Unsupported object \(object.type)", error: true), effects: [], next: next())
        }
    }

    private func outgoingFrames(
        from object: WorkflowObject,
        arguments: [String],
        variables: [String: String],
        modifier: WorkflowModifier,
        branch: String? = nil
    ) -> [WorkflowFrame] {
        var links = workflow.outgoing(from: object.id)
        if object.kind == .conditional {
            if let branch {
                links = links.filter { $0.sourceOutputUID == branch }
            } else {
                links = links.filter { ($0.sourceOutputUID ?? "").isEmpty }
            }
        } else {
            let modifierLinks = links.filter { $0.modifiers != 0 && ($0.modifiers & modifier.rawValue) == $0.modifiers }
            if !modifierLinks.isEmpty {
                links = Array(modifierLinks.prefix(1))
            } else {
                links = links.filter { $0.modifiers == 0 }
            }
        }
        return links.map { WorkflowFrame(objectID: $0.destination, arguments: arguments, variables: variables, modifier: modifier) }
    }

    private func conditionLabel(in object: WorkflowObject, uid: String) -> String? {
        let conditions = object.config["conditions"]?.arrayValue ?? []
        for condition in conditions {
            guard let bits = condition.objectValue else { continue }
            if bits[string: "uid"] == uid {
                let label = bits[string: "outputlabel"]
                return label.isEmpty ? uid : label
            }
        }
        return nil
    }

    private func conditionalBranch(_ object: WorkflowObject, query: String, variables: [String: String], rootURL: URL) -> String? {
        let conditions = object.config["conditions"]?.arrayValue ?? []
        for condition in conditions {
            guard let bits = condition.objectValue else { continue }
            let input = WorkflowTemplate.expand(bits[string: "inputstring"].isEmpty ? query : bits[string: "inputstring"], query: query, variables: variables, rootURL: rootURL)
            let pattern = WorkflowTemplate.expand(bits[string: "matchstring"], query: query, variables: variables, rootURL: rootURL)
            let mode = bits[integer: "matchmode"]
            let caseSensitive = bits["matchcasesensitive"]?.boolValue ?? false
            if WorkflowTemplate.conditionalMatches(input, pattern: pattern, mode: mode, caseSensitive: caseSensitive) {
                return bits[string: "uid"]
            }
        }
        return nil
    }

    private func readTextFile(_ relativePath: String) -> String? {
        guard !relativePath.isEmpty else { return nil }
        let url = relativePath.hasPrefix("/") ? URL(fileURLWithPath: relativePath) : rootURL.appendingPathComponent(relativePath)
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

public enum WorkflowTemplate {
    public static func expand(_ text: String, query: String, variables: [String: String], escaping: Int = 0, rootURL: URL? = nil) -> String {
        guard !text.isEmpty else { return text }
        var result = text
        for _ in 0..<3 {
            let before = result
            result = replaceQuery(in: result, query: query, escaping: escaping)
            for (key, value) in variables {
                result = result.replacingOccurrences(of: "{var:\(key)}", with: value)
            }
            if before == result { break }
        }
        result = result.replacingOccurrences(of: "{date}", with: dateString("yyyy-MM-dd"))
        result = result.replacingOccurrences(of: "{time}", with: dateString("HH:mm:ss"))
        result = result.replacingOccurrences(of: "{datetime}", with: dateString("yyyy-MM-dd HH:mm:ss"))
        if result.contains("{uuid}") { result = result.replacingOccurrences(of: "{uuid}", with: UUID().uuidString) }
        if let rootURL {
            result = result.replacingOccurrences(of: "{workflow_dir}", with: rootURL.path)
            result = result.replacingOccurrences(of: "{workflow}", with: rootURL.path)
        }
        return result
    }

    /// Alfred's Conditional utility exposes five comparisons: equal, not
    /// equal, greater than, less than and regex.
    public static func conditionalMatches(_ input: String, pattern: String, mode: Int, caseSensitive: Bool) -> Bool {
        let lhs = caseSensitive ? input : input.lowercased()
        let rhs = caseSensitive ? pattern : pattern.lowercased()
        switch mode {
        case 0: return lhs == rhs
        case 1: return lhs != rhs
        case 2:
            guard let a = Double(input), let b = Double(pattern) else { return false }
            return a > b
        case 3:
            guard let a = Double(input), let b = Double(pattern) else { return false }
            return a < b
        case 4:
            guard let regex = try? NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive]) else { return false }
            let range = NSRange(input.startIndex..., in: input)
            return regex.firstMatch(in: input, range: range) != nil
        default: return lhs == rhs
        }
    }

    /// The legacy Filter utility exposes equal, not equal and regex.
    public static func filterMatches(_ input: String, pattern: String, mode: Int, caseSensitive: Bool) -> Bool {
        switch mode {
        case 1: return caseSensitive ? input != pattern : input.lowercased() != pattern.lowercased()
        case 2:
            guard let regex = try? NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive]) else { return false }
            let range = NSRange(input.startIndex..., in: input)
            return regex.firstMatch(in: input, range: range) != nil
        default: return caseSensitive ? input == pattern : input.lowercased() == pattern.lowercased()
        }
    }

    private static func replaceQuery(in text: String, query: String, escaping: Int) -> String {
        guard text.contains("{query}") else { return text }
        var result = ""
        var index = text.startIndex
        while let range = text.range(of: "{query}", range: index..<text.endIndex) {
            result += text[index..<range.lowerBound]
            let quoted = quoteContext(text, at: range.lowerBound)
            result += escapeQuery(query, mask: escaping, quote: quoted)
            index = range.upperBound
        }
        result += text[index...]
        return result
    }

    private enum QuoteContext {
        case none
        case single
        case double
    }

    private static func quoteContext(_ text: String, at index: String.Index) -> QuoteContext {
        var single = false
        var double = false
        var escaped = false
        var cursor = text.startIndex
        while cursor < index {
            let character = text[cursor]
            if escaped { escaped = false }
            else if character == "\\" { escaped = true }
            else if character == "'" && !double { single.toggle() }
            else if character == "\"" && !single { double.toggle() }
            cursor = text.index(after: cursor)
        }
        if single { return .single }
        if double { return .double }
        return .none
    }

    private static func escapeQuery(_ query: String, mask: Int, quote: QuoteContext) -> String {
        guard mask != 0 else { return query }
        var result = ""
        for character in query {
            switch quote {
            case .single:
                if character == "'" { result += "'\\''" } else { result.append(character) }
            case .double:
                if character == "\\" || character == "\"" || character == "$" || character == "`" {
                    result += "\\\(character)"
                } else {
                    result.append(character)
                }
            case .none:
                if character == "\\" || character == "\"" || character == "$" || character == "`" {
                    result += "\\\(character)"
                } else if mask & 1 != 0, character == " " {
                    result += "\\ "
                } else if mask & 64 != 0, "&;|<>(){}[]*?!#~".contains(character) {
                    result += "\\\(character)"
                } else {
                    result.append(character)
                }
            }
        }
        return result
    }

    private static func dateString(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: Date())
    }
}

public enum WorkflowScriptFilterParser {
    public static func parse(_ text: String) -> WorkflowScriptFilterResult {
        for object in jsonObjects(in: text) {
            if let result = parseJSONObject(object) { return result }
        }
        if let result = parseXML(text) { return result }
        return WorkflowScriptFilterResult(items: [])
    }

    public static func parseListItems(_ text: String) -> [WorkflowItem] {
        guard let data = text.data(using: .utf8),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return rows.map { item(from: $0, basePath: nil) }
    }

    public static func filter(_ items: [WorkflowItem], query: String, mode: Int) -> [WorkflowItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }
        return items.filter { item in
            let haystack = item.match.isEmpty ? item.title : item.match
            return matches(haystack, query: needle, mode: mode)
        }
    }

    private static func matches(_ text: String, query: String, mode: Int) -> Bool {
        let haystack = fold(text)
        let needle = fold(query)
        guard !needle.isEmpty else { return true }
        switch mode {
        case 1:
            return haystack.hasPrefix(needle)
        case 2:
            let words = Set(needle.split(separator: " ").map(String.init))
            let hay = Set(haystack.split { !$0.isLetter && !$0.isNumber }.map(String.init))
            return words.isSubset(of: hay)
        case 3:
            var cursor = haystack.startIndex
            for word in needle.split(separator: " ") {
                guard let range = haystack[cursor...].range(of: word) else { return false }
                cursor = range.upperBound
            }
            return true
        default:
            return wordStartPrefix(haystack, needle)
        }
    }

    private static func wordStartPrefix(_ haystack: String, _ needle: String) -> Bool {
        var cursor = haystack.startIndex
        while let range = haystack[cursor...].range(of: needle) {
            if range.lowerBound == haystack.startIndex {
                return true
            }
            let previous = haystack[haystack.index(before: range.lowerBound)]
            if !previous.isLetter && !previous.isNumber {
                return true
            }
            cursor = range.upperBound
        }
        return false
    }

    private static func jsonObjects(in text: String) -> [[String: Any]] {
        let chars = Array(text)
        var results: [[String: Any]] = []
        var index = 0
        while index < chars.count {
            if chars[index] == "{", let end = balancedEnd(chars, from: index) {
                let slice = String(chars[index...end])
                if let data = slice.data(using: .utf8),
                   let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    results.append(object)
                }
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
                if escape { escape = false; continue }
                if character == "\\" { escape = true; continue }
                if character == "\"" { inString = false }
                continue
            }
            if character == "\"" { inString = true; continue }
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { return index }
            }
        }
        return nil
    }

    private static func parseJSONObject(_ object: [String: Any]) -> WorkflowScriptFilterResult? {
        if let rows = object["items"] as? [[String: Any]] {
            let variables = (object["variables"] as? [String: Any] ?? [:]).compactMapValues { value in
                if let text = value as? String { return text }
                if let number = value as? NSNumber { return number.stringValue }
                return nil
            }
            return WorkflowScriptFilterResult(
                items: rows.map { item(from: $0, basePath: nil) },
                variables: variables,
                rerun: (object["rerun"] as? NSNumber)?.doubleValue
            )
        }
        if object["items"] is [Any] {
            return WorkflowScriptFilterResult(items: [])
        }
        return nil
    }

    private static func item(from row: [String: Any], basePath: String?) -> WorkflowItem {
        let arguments: [String]
        if let array = row["arg"] as? [Any] {
            arguments = array.compactMap { value in
                if let text = value as? String { return text }
                if let number = value as? NSNumber { return number.stringValue }
                return nil
            }
        } else if let text = row["arg"] as? String {
            arguments = [text]
        } else if let number = row["arg"] as? NSNumber {
            arguments = [number.stringValue]
        } else {
            arguments = []
        }
        let icon = row["icon"] as? [String: Any] ?? [:]
        let iconPath = icon["path"] as? String ?? (row["icon"] as? String) ?? ""
        var mods: [String: WorkflowItemMod] = [:]
        for (key, value) in row["mods"] as? [String: Any] ?? [:] {
            guard let value = value as? [String: Any] else { continue }
            let modArgs: [String]?
            if let array = value["arg"] as? [Any] {
                modArgs = array.compactMap { $0 as? String }
            } else if let text = value["arg"] as? String {
                modArgs = [text]
            } else {
                modArgs = nil
            }
            mods[key] = WorkflowItemMod(
                valid: value["valid"] as? Bool,
                arguments: modArgs,
                subtitle: value["subtitle"] as? String,
                variables: (value["variables"] as? [String: Any] ?? [:]).compactMapValues { $0 as? String },
                iconPath: (value["icon"] as? [String: Any])?["path"] as? String
            )
        }
        return WorkflowItem(
            uid: row["uid"] as? String ?? "",
            title: row["title"] as? String ?? "",
            subtitle: row["subtitle"] as? String ?? "",
            arguments: arguments,
            valid: (row["valid"] as? Bool) ?? true,
            autocomplete: row["autocomplete"] as? String ?? "",
            match: row["match"] as? String ?? "",
            iconPath: iconPath,
            iconType: icon["type"] as? String ?? "",
            type: row["type"] as? String ?? "default",
            quickLookURL: row["quicklookurl"] as? String ?? "",
            variables: (row["variables"] as? [String: Any] ?? [:]).compactMapValues { $0 as? String },
            mods: mods
        )
    }

    private static func parseXML(_ text: String) -> WorkflowScriptFilterResult? {
        // Legacy workflows sometimes print a second XML document after the
        // first (for example Alfred-Workflow's error item). Parse the first
        // complete <items> document, matching Alfred's behaviour.
        guard let start = text.range(of: "<items"),
              let end = text.range(of: "</items>", range: start.upperBound..<text.endIndex) else { return nil }
        let document = String(text[start.lowerBound..<end.upperBound])
        let delegate = XMLItemDelegate()
        let parser = XMLParser(data: Data(document.utf8))
        parser.delegate = delegate
        guard parser.parse() else { return nil }
        return WorkflowScriptFilterResult(items: delegate.items)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
    }
}

private final class XMLItemDelegate: NSObject, XMLParserDelegate {
    var items: [WorkflowItem] = []
    private var current: WorkflowItem?
    private var text = ""
    private var element = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        element = elementName
        text = ""
        if elementName == "item" {
            let arg = attributeDict["arg"].map { [$0] } ?? []
            current = WorkflowItem(
                uid: attributeDict["uid"] ?? "",
                arguments: arg,
                valid: (attributeDict["valid"]?.lowercased() != "no"),
                autocomplete: attributeDict["autocomplete"] ?? "",
                type: attributeDict["type"] ?? "default"
            )
        } else if elementName == "icon" {
            current?.iconType = attributeDict["type"] ?? ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "title": current?.title = value
        case "subtitle": current?.subtitle = value
        case "arg": current?.arguments = [value]
        case "icon": current?.iconPath = value
        case "item":
            if let current { items.append(current) }
            current = nil
        default: break
        }
        text = ""
        element = ""
    }
}
