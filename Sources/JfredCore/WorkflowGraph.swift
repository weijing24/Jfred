import CoreFoundation
import Foundation

/// A type-erased value from an Alfred workflow `info.plist`. Workflows use a
/// small, fixed set of plist shapes, so keeping the original shape is more
/// useful than flattening every object into strings.
public indirect enum WorkflowValue: Codable, Equatable, Sendable {
    case string(String)
    case integer(Int)
    case number(Double)
    case boolean(Bool)
    case array([WorkflowValue])
    case object([String: WorkflowValue])
    case null

    public init(any value: Any?) {
        guard let value else { self = .null; return }
        if let value = value as? String {
            self = .string(value)
        } else if let value = value as? Bool {
            self = .boolean(value)
        } else if let value = value as? Int {
            self = .integer(value)
        } else if let value = value as? Double {
            self = .number(value)
        } else if let value = value as? NSNumber {
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                self = .boolean(value.boolValue)
            } else if value.doubleValue.rounded() == value.doubleValue, abs(value.doubleValue) < Double(Int.max) {
                self = .integer(value.intValue)
            } else {
                self = .number(value.doubleValue)
            }
        } else if let value = value as? [Any] {
            self = .array(value.map { WorkflowValue(any: $0) })
        } else if let value = value as? [String: Any] {
            self = .object(value.mapValues { WorkflowValue(any: $0) })
        } else {
            self = .string(String(describing: value))
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .integer(let value): return String(value)
        case .number(let value): return String(value)
        case .boolean(let value): return value ? "true" : "false"
        case .array, .object, .null: return nil
        }
    }

    public var intValue: Int? {
        switch self {
        case .integer(let value): return value
        case .number(let value): return Int(value)
        case .string(let value): return Int(value)
        case .boolean(let value): return value ? 1 : 0
        case .array, .object, .null: return nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .integer(let value): return Double(value)
        case .number(let value): return value
        case .string(let value): return Double(value)
        case .boolean(let value): return value ? 1 : 0
        case .array, .object, .null: return nil
        }
    }

    public var boolValue: Bool? {
        switch self {
        case .boolean(let value): return value
        case .integer(let value): return value != 0
        case .number(let value): return value != 0
        case .string(let value):
            switch value.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        case .array, .object, .null: return nil
        }
    }

    public var arrayValue: [WorkflowValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    public var objectValue: [String: WorkflowValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    public var anyValue: Any {
        switch self {
        case .string(let value): return value
        case .integer(let value): return value
        case .number(let value): return value
        case .boolean(let value): return value
        case .array(let value): return value.map(\.anyValue)
        case .object(let value): return value.mapValues(\.anyValue)
        case .null: return NSNull()
        }
    }

    public var displayText: String {
        switch self {
        case .string(let value): return value
        case .integer(let value): return String(value)
        case .number(let value): return String(value)
        case .boolean(let value): return value ? "true" : "false"
        case .array(let value): return value.map(\.displayText).joined(separator: ", ")
        case .object(let value): return value.keys.sorted().joined(separator: ", ")
        case .null: return ""
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([WorkflowValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: WorkflowValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported workflow value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

public extension Dictionary where Key == String, Value == WorkflowValue {
    subscript(string key: String) -> String {
        get { self[key]?.stringValue ?? "" }
        set { self[key] = .string(newValue) }
    }

    subscript(integer key: String) -> Int {
        get { self[key]?.intValue ?? 0 }
        set { self[key] = .integer(newValue) }
    }

    subscript(boolean key: String) -> Bool {
        get { self[key]?.boolValue ?? false }
        set { self[key] = .boolean(newValue) }
    }

    func object(_ key: String) -> [String: WorkflowValue] {
        self[key]?.objectValue ?? [:]
    }

    func strings(_ key: String) -> [String: String] {
        object(key).compactMapValues(\.stringValue)
    }

    mutating func setObject(_ key: String, _ value: [String: WorkflowValue]) {
        self[key] = .object(value)
    }
}

public struct WorkflowPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double = 0, y: Double = 0) {
        self.x = x
        self.y = y
    }
}

public enum WorkflowID {
    /// Stable UUIDs keep imported graph nodes and connections identifiable
    /// across reloads without writing Jfred-only IDs into the workflow folder.
    public static func stable(_ key: String) -> UUID {
        var first: UInt64 = 14_695_981_039_346_656_037
        var second: UInt64 = 1_099_511_628_211
        for byte in key.utf8 {
            first = (first ^ UInt64(byte)) &* 1_099_511_628_211
            second = (second &+ UInt64(byte)) &* 14_695_981_039_346_656_037
        }
        var bytes: [UInt8] = []
        for value in [first, second] {
            bytes.append(UInt8(truncatingIfNeeded: value >> 56))
            bytes.append(UInt8(truncatingIfNeeded: value >> 48))
            bytes.append(UInt8(truncatingIfNeeded: value >> 40))
            bytes.append(UInt8(truncatingIfNeeded: value >> 32))
            bytes.append(UInt8(truncatingIfNeeded: value >> 24))
            bytes.append(UInt8(truncatingIfNeeded: value >> 16))
            bytes.append(UInt8(truncatingIfNeeded: value >> 8))
            bytes.append(UInt8(truncatingIfNeeded: value))
        }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

public enum WorkflowObjectKind: String, Codable, CaseIterable, Sendable {
    case keyword
    case scriptFilter
    case listFilter
    case runScript
    case appleScript
    case terminal
    case openURL
    case openFile
    case revealFile
    case clipboard
    case largeType
    case notification
    case playSound
    case speak
    case argument
    case conditional
    case filter
    case junction
    case delay
    case debug
    case writeFile
    case externalTrigger
    case externalTriggerInput
    case hotkey
    case universalAction
    case automationTask
    case textView
    case userInterface
    case unknown

    public init(rawType: String) {
        let type = rawType.lowercased()
        switch type {
        case "alfred.workflow.input.keyword": self = .keyword
        case "alfred.workflow.input.scriptfilter": self = .scriptFilter
        case "alfred.workflow.input.listfilter": self = .listFilter
        case "alfred.workflow.action.script", "alfred.workflow.output.script": self = .runScript
        case "alfred.workflow.action.applescript": self = .appleScript
        case "alfred.workflow.action.terminalcommand": self = .terminal
        case "alfred.workflow.action.openurl", "alfred.workflow.action.url.open": self = .openURL
        case "alfred.workflow.action.openfile", "alfred.workflow.action.launchfiles": self = .openFile
        case "alfred.workflow.action.revealfile": self = .revealFile
        case "alfred.workflow.output.clipboard": self = .clipboard
        case "alfred.workflow.output.largetype": self = .largeType
        case "alfred.workflow.output.notification": self = .notification
        case "alfred.workflow.output.playsound": self = .playSound
        case "alfred.workflow.output.speak": self = .speak
        case "alfred.workflow.utility.argument": self = .argument
        case "alfred.workflow.utility.conditional": self = .conditional
        case "alfred.workflow.utility.filter": self = .filter
        case "alfred.workflow.utility.junction": self = .junction
        case "alfred.workflow.utility.delay": self = .delay
        case "alfred.workflow.utility.debug": self = .debug
        case "alfred.workflow.output.writefile": self = .writeFile
        case "alfred.workflow.output.callexternaltrigger": self = .externalTrigger
        case "alfred.workflow.trigger.external": self = .externalTriggerInput
        case "alfred.workflow.trigger.hotkey": self = .hotkey
        case "alfred.workflow.trigger.universalaction": self = .universalAction
        case "alfred.workflow.automation.task": self = .automationTask
        case "alfred.workflow.userinterface.text": self = .textView
        case "alfred.workflow.userinterface.image", "alfred.workflow.userinterface.grid", "alfred.workflow.userinterface.pdf": self = .userInterface
        default: self = .unknown
        }
    }

    public var rawType: String {
        switch self {
        case .keyword: return "alfred.workflow.input.keyword"
        case .scriptFilter: return "alfred.workflow.input.scriptfilter"
        case .listFilter: return "alfred.workflow.input.listfilter"
        case .runScript: return "alfred.workflow.action.script"
        case .appleScript: return "alfred.workflow.action.applescript"
        case .terminal: return "alfred.workflow.action.terminalcommand"
        case .openURL: return "alfred.workflow.action.openurl"
        case .openFile: return "alfred.workflow.action.openfile"
        case .revealFile: return "alfred.workflow.action.revealfile"
        case .clipboard: return "alfred.workflow.output.clipboard"
        case .largeType: return "alfred.workflow.output.largetype"
        case .notification: return "alfred.workflow.output.notification"
        case .playSound: return "alfred.workflow.output.playsound"
        case .speak: return "alfred.workflow.output.speak"
        case .argument: return "alfred.workflow.utility.argument"
        case .conditional: return "alfred.workflow.utility.conditional"
        case .filter: return "alfred.workflow.utility.filter"
        case .junction: return "alfred.workflow.utility.junction"
        case .delay: return "alfred.workflow.utility.delay"
        case .debug: return "alfred.workflow.utility.debug"
        case .writeFile: return "alfred.workflow.output.writefile"
        case .externalTrigger: return "alfred.workflow.output.callexternaltrigger"
        case .externalTriggerInput: return "alfred.workflow.trigger.external"
        case .hotkey: return "alfred.workflow.trigger.hotkey"
        case .universalAction: return "alfred.workflow.trigger.universalaction"
        case .automationTask: return "alfred.workflow.automation.task"
        case .textView: return "alfred.workflow.userinterface.text"
        case .userInterface: return "alfred.workflow.userinterface.image"
        case .unknown: return ""
        }
    }

    public var title: String {
        switch self {
        case .keyword: return "Keyword"
        case .scriptFilter: return "Script Filter"
        case .listFilter: return "List Filter"
        case .runScript: return "Run Script"
        case .appleScript: return "AppleScript"
        case .terminal: return "Terminal Command"
        case .openURL: return "Open URL"
        case .openFile: return "Open File"
        case .revealFile: return "Reveal in Finder"
        case .clipboard: return "Copy to Clipboard"
        case .largeType: return "Large Type"
        case .notification: return "Post Notification"
        case .playSound: return "Play Sound"
        case .speak: return "Speak"
        case .argument: return "Arg and Vars"
        case .conditional: return "Conditional"
        case .filter: return "Filter"
        case .junction: return "Junction"
        case .delay: return "Delay"
        case .debug: return "Debug"
        case .writeFile: return "Write File"
        case .externalTrigger: return "Call External Trigger"
        case .externalTriggerInput: return "External Trigger"
        case .hotkey: return "Hotkey"
        case .universalAction: return "Universal Action"
        case .automationTask: return "Automation Task"
        case .textView: return "Text View"
        case .userInterface: return "UI Object"
        case .unknown: return "Object"
        }
    }

    public var symbol: String {
        switch self {
        case .keyword: return "keyboard"
        case .scriptFilter: return "line.3.horizontal.decrease.circle"
        case .listFilter: return "list.bullet.rectangle"
        case .runScript: return "terminal"
        case .appleScript: return "applescript"
        case .terminal: return "terminal.fill"
        case .openURL: return "globe"
        case .openFile: return "doc"
        case .revealFile: return "magnifyingglass"
        case .clipboard: return "doc.on.doc"
        case .largeType: return "textformat.size"
        case .notification: return "bell"
        case .playSound: return "speaker.wave.2"
        case .speak: return "waveform"
        case .argument: return "slider.horizontal.3"
        case .conditional: return "arrow.triangle.branch"
        case .filter: return "line.3.horizontal.decrease"
        case .junction: return "point.3.connected.trianglepath.dotted"
        case .delay: return "clock"
        case .debug: return "ladybug"
        case .writeFile: return "square.and.arrow.down"
        case .externalTrigger: return "bolt"
        case .externalTriggerInput: return "bolt.circle"
        case .hotkey: return "command"
        case .universalAction: return "text.cursor"
        case .automationTask: return "gearshape.2"
        case .textView: return "text.alignleft"
        case .userInterface: return "rectangle.on.rectangle"
        case .unknown: return "questionmark.square.dashed"
        }
    }

    public var isSearchInput: Bool {
        switch self {
        case .keyword, .scriptFilter, .listFilter: return true
        default: return false
        }
    }
}

/// Popup order from Alfred 5's Hotkey and Universal Action configuration nibs.
/// The stored integer is the menu index.
public enum WorkflowTriggerLabels {
    public static let hotkeyActions = ["Pass through to workflow", "Show Alfred"]
    public static let hotkeyArguments = ["None", "Selection in macOS", "macOS Clipboard Contents", "macOS Find Pasteboard", "Text"]
    public static let universalArgumentCounts = ["Single", "Single and Multiple", "Multiple"]
    public static let hotkeyModifierModes = [
        "Simulate modifier keys released",
        "Wait until modifier keys are released",
        "Pass through modifier keys",
    ]
    public static let relatedAppModes = ["have focus", "don't have focus"]

    public static func hotkeyAction(_ index: Int) -> String { label(hotkeyActions, index) }
    public static func hotkeyArgument(_ index: Int) -> String { label(hotkeyArguments, index) }
    public static func universalArgumentCount(_ index: Int) -> String { label(universalArgumentCounts, index) }

    private static func label(_ labels: [String], _ index: Int) -> String {
        labels.indices.contains(index) ? labels[index] : labels[0]
    }
}

public struct WorkflowObject: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var alfredUID: String
    public var type: String
    public var config: [String: WorkflowValue]
    public var position: WorkflowPoint
    public var note: String
    public var colorIndex: Int
    public var version: Int

    public init(
        id: UUID = UUID(),
        alfredUID: String = "",
        type: String,
        config: [String: WorkflowValue] = [:],
        position: WorkflowPoint = WorkflowPoint(),
        note: String = "",
        colorIndex: Int = 0,
        version: Int = 1
    ) {
        self.id = id
        self.alfredUID = alfredUID
        self.type = type
        self.config = config
        self.position = position
        self.note = note
        self.colorIndex = colorIndex
        self.version = version
    }

    public init(kind: WorkflowObjectKind, config: [String: WorkflowValue] = [:], position: WorkflowPoint = WorkflowPoint()) {
        self.init(alfredUID: UUID().uuidString, type: kind.rawType, config: config, position: position)
    }

    public var kind: WorkflowObjectKind { WorkflowObjectKind(rawType: type) }

    public var title: String {
        let configured = config[string: "title"].trimmingCharacters(in: .whitespacesAndNewlines)
        return configured.isEmpty ? kind.title : configured
    }

    /// Name drawn above the object icon. Universal Action uses `name`; a Hotkey uses its argument mode.
    public var triggerCaption: String {
        switch kind {
        case .universalAction:
            return config[string: "name"].trimmingCharacters(in: .whitespacesAndNewlines)
        case .hotkey:
            let label = WorkflowTriggerLabels.hotkeyArgument(config[integer: "argument"])
            return label == "None" ? "" : label
        default:
            return ""
        }
    }

    public var relatedApps: [WorkflowRelatedApp] {
        let values = config["relatedApps"]?.arrayValue ?? []
        return values.compactMap { value in
            if let bundleID = value.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !bundleID.isEmpty {
                return WorkflowRelatedApp(name: bundleID, bundleID: bundleID)
            }
            guard let object = value.objectValue else { return nil }
            let bundleID = object[string: "bundleid"].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bundleID.isEmpty else { return nil }
            let name = object[string: "name"].trimmingCharacters(in: .whitespacesAndNewlines)
            return WorkflowRelatedApp(name: name.isEmpty ? bundleID : name, bundleID: bundleID)
        }
    }

    public var keyword: String {
        get { config[string: "keyword"] }
        set { config["keyword"] = .string(newValue) }
    }

    public var script: String {
        get { config[string: "script"] }
        set { config["script"] = .string(newValue) }
    }

    public var scriptFile: String {
        get { config[string: "scriptfile"] }
        set { config["scriptfile"] = .string(newValue) }
    }

    public var scriptType: Int {
        get { config[integer: "type"] }
        set { config["type"] = .integer(newValue) }
    }

    public var scriptArgumentType: Int {
        get { config[integer: "scriptargtype"] }
        set { config["scriptargtype"] = .integer(newValue) }
    }

    public var escaping: Int {
        get { config[integer: "escaping"] }
        set { config["escaping"] = .integer(newValue) }
    }

    public var withSpace: Bool {
        get { config["withspace"]?.boolValue ?? true }
        set { config["withspace"] = .boolean(newValue) }
    }

    public var argumentType: Int {
        get { config[integer: "argumenttype"] }
        set { config["argumenttype"] = .integer(newValue) }
    }

    public var filtersResults: Bool {
        get { config["alfredfiltersresults"]?.boolValue ?? false }
        set { config["alfredfiltersresults"] = .boolean(newValue) }
    }

    public var filterMatchMode: Int {
        get { config[integer: "alfredfiltersresultsmatchmode"] }
        set { config["alfredfiltersresultsmatchmode"] = .integer(newValue) }
    }

    public var subtext: String {
        get { config[string: "subtext"] }
        set { config["subtext"] = .string(newValue) }
    }
}

public struct WorkflowRelatedApp: Equatable, Sendable, Identifiable {
    public var name: String
    public var bundleID: String
    public var id: String { bundleID }

    public init(name: String, bundleID: String) {
        self.name = name
        self.bundleID = bundleID
    }
}

public struct WorkflowConnection: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var source: UUID
    public var destination: UUID
    public var modifiers: Int
    public var subtext: String
    public var sourceOutputUID: String?
    public var closeVitor: Bool

    public init(
        id: UUID = UUID(),
        source: UUID,
        destination: UUID,
        modifiers: Int = 0,
        subtext: String = "",
        sourceOutputUID: String? = nil,
        closeVitor: Bool = false
    ) {
        self.id = id
        self.source = source
        self.destination = destination
        self.modifiers = modifiers
        self.subtext = subtext
        self.sourceOutputUID = sourceOutputUID
        self.closeVitor = closeVitor
    }
}

public struct Workflow: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var author: String
    public var symbol: String
    public var tint: String
    public var enabled: Bool
    public var builtin: String?
    public var objects: [WorkflowObject]
    public var connections: [WorkflowConnection]
    public var hotkey: Hotkey?
    public var bundleID: String
    public var details: String
    public var readme: String
    public var website: String
    public var category: String
    public var version: String
    public var variables: [String: String]
    public var userConfiguration: [WorkflowValue]
    public var rootPath: String?
    /// 0 = flat legacy state, 1 = imported Alfred graph, 2 = native Jfred graph.
    public var definitionVersion: Int

    public init(
        id: UUID = UUID(),
        name: String,
        keyword: String = "",
        author: String = "",
        symbol: String = "bolt.fill",
        tint: String = "561D7E",
        enabled: Bool = true,
        builtin: String? = nil,
        actions: [WorkflowAction] = [],
        hotkey: Hotkey? = nil,
        bundleID: String = "",
        details: String = "",
        readme: String = "",
        website: String = "",
        category: String = "Uncategorised",
        version: String = "1.0",
        variables: [String: String] = [:],
        userConfiguration: [WorkflowValue] = [],
        rootPath: String? = nil,
        definitionVersion: Int = 2
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.symbol = symbol
        self.tint = tint
        self.enabled = enabled
        self.builtin = builtin
        self.hotkey = hotkey
        self.bundleID = bundleID
        self.details = details
        self.readme = readme
        self.website = website
        self.category = category
        self.version = version
        self.variables = variables
        self.userConfiguration = []
        self.rootPath = rootPath
        self.definitionVersion = 2
        self.objects = []
        self.connections = []
        if !keyword.isEmpty || !actions.isEmpty {
            var keywordConfig: [String: WorkflowValue] = ["keyword": .string(keyword), "withspace": .boolean(false)]
            if !keyword.isEmpty { keywordConfig["title"] = .string(name) }
            let keywordObject = WorkflowObject(kind: .keyword, config: keywordConfig)
            objects.append(keywordObject)
            var previous = keywordObject.id
            for action in actions {
                let object = Workflow.legacyObject(for: action)
                objects.append(object)
                connections.append(WorkflowConnection(source: previous, destination: object.id))
                previous = object.id
            }
        }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        author: String,
        symbol: String,
        tint: String,
        enabled: Bool,
        builtin: String?,
        objects: [WorkflowObject],
        connections: [WorkflowConnection],
        hotkey: Hotkey? = nil,
        bundleID: String = "",
        details: String = "",
        readme: String = "",
        website: String = "",
        category: String = "Uncategorised",
        version: String = "1.0",
        variables: [String: String] = [:],
        userConfiguration: [WorkflowValue] = [],
        rootPath: String? = nil,
        definitionVersion: Int = 2
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.symbol = symbol
        self.tint = tint
        self.enabled = enabled
        self.builtin = builtin
        self.objects = objects
        self.connections = connections
        self.hotkey = hotkey
        self.bundleID = bundleID
        self.details = details
        self.readme = readme
        self.website = website
        self.category = category
        self.version = version
        self.variables = variables
        self.userConfiguration = userConfiguration
        self.rootPath = rootPath
        self.definitionVersion = definitionVersion
        normalizeLayout()
    }

    /// Defaults from User Configuration, in the form Alfred puts on the
    /// environment: checkboxes are `1` or `0`, sliders are their number.
    public var configurationVariables: [String: String] {
        var result: [String: String] = [:]
        for item in userConfiguration {
            guard let field = item.objectValue else { continue }
            let name = field[string: "variable"].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, let value = Self.configurationValue(field) else { continue }
            result[name] = value
        }
        return result
    }

    /// User Configuration defaults, then values the user saved on the workflow.
    /// A saved value replaces the default for the same key.
    public var resolvedVariables: [String: String] {
        configurationVariables.merging(variables) { _, saved in saved }
    }

    /// Substitutes `{var:name}` in a keyword. An unknown placeholder is left
    /// in place so it does not match a typed query by accident.
    public func expandedKeyword(_ keyword: String) -> String {
        var result = keyword
        for (key, value) in resolvedVariables {
            result = result.replacingOccurrences(of: "{var:\(key)}", with: value)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func configurationValue(_ field: [String: WorkflowValue]) -> String? {
        let config = field.object("config")
        switch field[string: "type"] {
        case "checkbox":
            return config["default"]?.boolValue == true ? "1" : "0"
        case "slider":
            guard let number = config["defaultvalue"] else { return nil }
            if let int = number.intValue, number.doubleValue == Double(int) { return String(int) }
            return number.stringValue
        default:
            guard let value = config["default"] else { return nil }
            if case .boolean(let flag) = value { return flag ? "1" : "0" }
            return value.stringValue
        }
    }

    public var keyword: String {
        get {
            for object in objects where object.kind.isSearchInput {
                let value = object.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
            return ""
        }
        set {
            if let index = objects.firstIndex(where: { $0.kind.isSearchInput }) {
                objects[index].keyword = newValue
                return
            }
            let object = WorkflowObject(kind: .keyword, config: ["keyword": .string(newValue)], position: WorkflowPoint(x: 40, y: 40))
            objects.insert(object, at: 0)
        }
    }

    public var actions: [WorkflowAction] {
        get { objects.compactMap { WorkflowAction(object: $0) } }
        set { rebuildActions(newValue) }
    }

    public var scriptFilters: [WorkflowObject] {
        objects.filter { $0.kind == .scriptFilter }
    }

    public var searchInputs: [WorkflowObject] {
        objects.filter(\.kind.isSearchInput)
    }

    public var hotkeyObject: WorkflowObject? {
        objects.first { $0.kind == .hotkey }
    }

    public func object(id: UUID) -> WorkflowObject? {
        objects.first { $0.id == id }
    }

    public func outgoing(from id: UUID) -> [WorkflowConnection] {
        connections.filter { $0.source == id }
    }

    public func defaultOutgoing(from id: UUID) -> WorkflowConnection? {
        outgoing(from: id).first { $0.modifiers == 0 && ($0.sourceOutputUID ?? "").isEmpty }
    }

    public func downstream(of id: UUID) -> [WorkflowObject] {
        outgoing(from: id).compactMap { connection in objects.first { $0.id == connection.destination } }
    }

    public mutating func removeObject(_ id: UUID) {
        objects.removeAll { $0.id == id }
        connections.removeAll { $0.source == id || $0.destination == id }
    }

    public mutating func connect(_ source: UUID, _ destination: UUID, modifiers: Int = 0, sourceOutputUID: String? = nil, subtext: String = "") {
        connections.removeAll { $0.source == source && $0.destination == destination && $0.modifiers == modifiers && $0.sourceOutputUID == sourceOutputUID }
        connections.append(WorkflowConnection(source: source, destination: destination, modifiers: modifiers, subtext: subtext, sourceOutputUID: sourceOutputUID))
    }

    public mutating func disconnect(_ source: UUID, _ destination: UUID) {
        connections.removeAll { $0.source == source && $0.destination == destination }
    }

    /// Alfred stores canvas coordinates in `uidata`. Native Jfred workflows are
    /// laid out left-to-right when they have no useful coordinates.
    public mutating func normalizeLayout() {
        let needsLayout = objects.allSatisfy { $0.position.x == 0 && $0.position.y == 0 }
        if needsLayout {
            for (index, _) in objects.enumerated() {
                objects[index].position = WorkflowPoint(x: 40 + Double(index % 3) * 240, y: 40 + Double(index / 3) * 150)
            }
        }
    }

    private mutating func rebuildActions(_ actions: [WorkflowAction]) {
        let oldActionIDs = Set(objects.filter { WorkflowAction(object: $0) != nil }.map(\.id))
        objects.removeAll { oldActionIDs.contains($0.id) }
        connections.removeAll { oldActionIDs.contains($0.source) || oldActionIDs.contains($0.destination) }
        var previous = objects.first(where: { $0.kind.isSearchInput })?.id
        if previous == nil {
            let input = WorkflowObject(kind: .keyword, config: ["keyword": .string(keyword)], position: WorkflowPoint(x: 40, y: 40))
            objects.insert(input, at: 0)
            previous = input.id
        }
        for action in actions {
            let object = Workflow.legacyObject(for: action)
            objects.append(object)
            if let previous { connections.append(WorkflowConnection(source: previous, destination: object.id)) }
            previous = object.id
        }
    }

    private static func legacyObject(for action: WorkflowAction) -> WorkflowObject {
        switch action.kind {
        case .openURL:
            return WorkflowObject(kind: .openURL, config: ["url": .string(action.value)])
        case .openApp:
            return WorkflowObject(kind: .openFile, config: ["path": .string(action.value)])
        case .shell:
            return WorkflowObject(kind: .runScript, config: ["script": .string(action.value), "type": .integer(0)])
        case .copy:
            return WorkflowObject(kind: .clipboard, config: ["clipboardtext": .string(action.value)])
        case .largeType:
            return WorkflowObject(kind: .largeType, config: ["text": .string(action.value)])
        case .appleScript:
            return WorkflowObject(kind: .appleScript, config: ["script": .string(action.value)])
        case .terminal:
            return WorkflowObject(kind: .terminal, config: ["command": .string(action.value)])
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, author, symbol, tint, enabled, builtin, objects, connections, hotkey
        case bundleID, details, readme, website, category, version, variables, userConfiguration, rootPath, definitionVersion
        case legacyKeyword = "keyword"
        case legacyActions = "actions"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedName = try container.decodeIfPresent(String.self, forKey: .name) ?? "Workflow"
        let decodedBundle = try container.decodeIfPresent(String.self, forKey: .bundleID) ?? ""
        let decodedBuiltin = try container.decodeIfPresent(String.self, forKey: .builtin)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
            ?? WorkflowID.stable(decodedBuiltin ?? (decodedBundle.isEmpty ? decodedName : decodedBundle))
        name = decodedName
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ?? "bolt.fill"
        tint = try container.decodeIfPresent(String.self, forKey: .tint) ?? "561D7E"
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        builtin = decodedBuiltin
        hotkey = try container.decodeIfPresent(Hotkey.self, forKey: .hotkey)
        bundleID = decodedBundle
        details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
        readme = try container.decodeIfPresent(String.self, forKey: .readme) ?? ""
        website = try container.decodeIfPresent(String.self, forKey: .website) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Uncategorised"
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
        variables = try container.decodeIfPresent([String: String].self, forKey: .variables) ?? [:]
        userConfiguration = try container.decodeIfPresent([WorkflowValue].self, forKey: .userConfiguration) ?? []
        rootPath = try container.decodeIfPresent(String.self, forKey: .rootPath)
        let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .definitionVersion)
        objects = try container.decodeIfPresent([WorkflowObject].self, forKey: .objects) ?? []
        connections = try container.decodeIfPresent([WorkflowConnection].self, forKey: .connections) ?? []
        let legacyKeyword = try container.decodeIfPresent(String.self, forKey: .legacyKeyword) ?? ""
        let legacyActions = try container.decodeIfPresent([WorkflowAction].self, forKey: .legacyActions) ?? []
        definitionVersion = decodedVersion ?? (objects.isEmpty && (!legacyKeyword.isEmpty || !legacyActions.isEmpty) ? 0 : 1)
        if objects.isEmpty && (!legacyKeyword.isEmpty || !legacyActions.isEmpty) {
            var inputConfig: [String: WorkflowValue] = ["keyword": .string(legacyKeyword), "withspace": .boolean(false)]
            if !legacyKeyword.isEmpty { inputConfig["title"] = .string(name) }
            let input = WorkflowObject(kind: .keyword, config: inputConfig, position: WorkflowPoint(x: 40, y: 40))
            objects = [input]
            var previous = input.id
            for (index, action) in legacyActions.enumerated() {
                let object = Workflow.legacyObject(for: action)
                objects.append(object)
                connections.append(WorkflowConnection(source: previous, destination: object.id))
                previous = object.id
                if index > 200 { break }
            }
        }
        normalizeLayout()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(author, forKey: .author)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(tint, forKey: .tint)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(builtin, forKey: .builtin)
        try container.encode(objects, forKey: .objects)
        try container.encode(connections, forKey: .connections)
        try container.encodeIfPresent(hotkey, forKey: .hotkey)
        try container.encode(bundleID, forKey: .bundleID)
        try container.encode(details, forKey: .details)
        try container.encode(readme, forKey: .readme)
        try container.encode(website, forKey: .website)
        try container.encode(category, forKey: .category)
        try container.encode(version, forKey: .version)
        try container.encode(variables, forKey: .variables)
        try container.encode(userConfiguration, forKey: .userConfiguration)
        try container.encodeIfPresent(rootPath, forKey: .rootPath)
        try container.encode(definitionVersion, forKey: .definitionVersion)
        // Written for older Jfred builds that only understood the flat model.
        try container.encode(keyword, forKey: .legacyKeyword)
        try container.encode(actions, forKey: .legacyActions)
    }
}

public enum WorkflowImporter {
    public static func workflow(
        from info: [String: Any],
        rootPath: String? = nil,
        id: UUID? = nil,
        enabledOverride: Bool? = nil
    ) -> Workflow? {
        let named = string(info["name"]) ?? ""
        let rawBundle = string(info["bundleid"]) ?? ""
        let fallback = rootPath.map { URL(fileURLWithPath: $0, isDirectory: true).lastPathComponent } ?? ""
        let bundleID = !rawBundle.isEmpty ? rawBundle : (!named.isEmpty ? named : fallback)
        guard !bundleID.isEmpty else { return nil }
        let name = !named.isEmpty ? named : bundleID
        let author = string(info["createdby"]) ?? "Imported"
        let rawObjects = info["objects"] as? [[String: Any]] ?? []
        let uiData = info["uidata"] as? [String: Any] ?? [:]
        var uidMap: [String: UUID] = [:]
        var objects: [WorkflowObject] = []
        for raw in rawObjects {
            guard let uid = string(raw["uid"]), let type = string(raw["type"]) else { continue }
            let objectID = WorkflowID.stable("\(bundleID):\(uid)")
            uidMap[uid] = objectID
            let ui = uiData[uid] as? [String: Any] ?? [:]
            let position = WorkflowPoint(
                x: number(ui["xpos"]) ?? 0,
                y: number(ui["ypos"]) ?? 0
            )
            objects.append(WorkflowObject(
                id: objectID,
                alfredUID: uid,
                type: type,
                config: (raw["config"] as? [String: Any] ?? [:]).mapValues { WorkflowValue(any: $0) },
                position: position,
                note: string(ui["note"]) ?? "",
                colorIndex: Int(number(ui["colorindex"]) ?? 0),
                version: Int(number(raw["version"]) ?? 1)
            ))
        }
        var connections: [WorkflowConnection] = []
        let rawConnections = info["connections"] as? [String: Any] ?? [:]
        for (sourceUID, rawLinks) in rawConnections {
            guard let source = uidMap[sourceUID], let links = rawLinks as? [[String: Any]] else { continue }
            for link in links {
                guard let destinationUID = string(link["destinationuid"]), let destination = uidMap[destinationUID] else { continue }
                connections.append(WorkflowConnection(
                    id: WorkflowID.stable("\(bundleID):\(sourceUID):\(destinationUID):\(string(link["sourceoutputuid"]) ?? ""):\(Int(number(link["modifiers"]) ?? 0))"),
                    source: source,
                    destination: destination,
                    modifiers: Int(number(link["modifiers"]) ?? 0),
                    subtext: string(link["modifiersubtext"]) ?? "",
                    sourceOutputUID: string(link["sourceoutputuid"]),
                    closeVitor: (link["vitoclose"] as? Bool) ?? false
                ))
            }
        }
        let variables = (info["variables"] as? [String: Any] ?? [:]).compactMapValues { string($0) }
        let userConfiguration = (info["userconfigurationconfig"] as? [Any] ?? []).map { WorkflowValue(any: $0) }
        let hotkeyObject = objects.first { $0.kind == .hotkey }
        let hotkey: Hotkey? = hotkeyObject.flatMap { object in
            guard let code = object.config["hotkey"]?.intValue, let modifiers = object.config["hotmod"]?.intValue, code != 0 else { return nil }
            return Hotkey(keyCode: UInt16(truncatingIfNeeded: code), modifiers: UInt(truncatingIfNeeded: modifiers))
        }
        let enabled = enabledOverride ?? !bool(info["disabled"])
        return Workflow(
            id: id ?? WorkflowID.stable(bundleID),
            name: name,
            author: author,
            symbol: "puzzlepiece.extension",
            tint: tint(for: bundleID),
            enabled: enabled,
            builtin: bundleID,
            objects: objects,
            connections: connections,
            hotkey: hotkey,
            bundleID: bundleID,
            details: string(info["description"]) ?? "",
            readme: string(info["readme"]) ?? "",
            website: string(info["webaddress"]) ?? "",
            category: string(info["category"]) ?? "Uncategorised",
            version: string(info["version"]) ?? "1.0",
            variables: variables,
            userConfiguration: userConfiguration,
            rootPath: rootPath,
            definitionVersion: 1
        )
    }

    public static func tint(for bundle: String) -> String {
        let palette = ["6C5CE7", "0984E3", "00B894", "E17055", "FDCB6E", "8E44AD", "2D3436", "C0392B", "16A085"]
        let sum = bundle.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }

    private static func string(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    private static func bool(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return false
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }
}

extension WorkflowAction {
    init?(object: WorkflowObject) {
        switch object.kind {
        case .openURL:
            self.init(kind: .openURL, value: object.config[string: "url"])
        case .openFile:
            self.init(kind: .openApp, value: object.config[string: "path"])
        case .runScript:
            self.init(kind: .shell, value: object.script)
        case .clipboard:
            self.init(kind: .copy, value: object.config[string: "clipboardtext"])
        case .largeType:
            self.init(kind: .largeType, value: object.config[string: "text"])
        case .appleScript:
            self.init(kind: .appleScript, value: object.script)
        case .terminal:
            self.init(kind: .terminal, value: object.config[string: "command"])
        default:
            return nil
        }
    }
}
