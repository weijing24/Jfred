import Foundation

/// Everything `state.json` holds. Since clips and usage moved to their own
/// files, `state.json` keeps empty `clips` and `usage` arrays: older Jfred
/// releases require both keys and would otherwise fail to read the file.
public struct DiskState: Codable, Equatable, Sendable {
    public var preferences: Preferences
    public var workflows: [Workflow]
    public var snippets: [Snippet]
    public var clips: [ClipItem]
    public var usage: [UsageEvent]
    public var knowledge: [String: String]
    public var selections: [String: SelectionStat]

    public var skippedWorkflowCount = 0

    public init(preferences: Preferences, workflows: [Workflow], snippets: [Snippet], clips: [ClipItem], usage: [UsageEvent], knowledge: [String: String], selections: [String: SelectionStat]) {
        self.preferences = preferences
        self.workflows = workflows
        self.snippets = snippets
        self.clips = clips
        self.usage = usage
        self.knowledge = knowledge
        self.selections = selections
        self.skippedWorkflowCount = 0
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferences = try container.decode(Preferences.self, forKey: .preferences)
        if let lossy = try container.decodeIfPresent(LossyDecodableArray<Workflow>.self, forKey: .workflows) {
            workflows = lossy.elements
            skippedWorkflowCount = lossy.skippedIndexes.count
            for index in lossy.skippedIndexes {
                let line = "Jfred: skipped unreadable workflow at index \(index) in state.json\n"
                FileHandle.standardError.write(Data(line.utf8))
            }
        } else {
            workflows = []
            skippedWorkflowCount = 0
        }
        snippets = try container.decode([Snippet].self, forKey: .snippets)
        clips = try container.decodeIfPresent([ClipItem].self, forKey: .clips) ?? []
        usage = try container.decodeIfPresent([UsageEvent].self, forKey: .usage) ?? []
        knowledge = try container.decode([String: String].self, forKey: .knowledge)
        selections = try container.decodeIfPresent([String: SelectionStat].self, forKey: .selections) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(preferences, forKey: .preferences)
        try container.encode(workflows, forKey: .workflows)
        try container.encode(snippets, forKey: .snippets)
        try container.encode(clips, forKey: .clips)
        try container.encode(usage, forKey: .usage)
        try container.encode(knowledge, forKey: .knowledge)
        try container.encode(selections, forKey: .selections)
    }

    private enum CodingKeys: String, CodingKey {
        case preferences, workflows, snippets, clips, usage, knowledge, selections
    }

    public static func == (lhs: DiskState, rhs: DiskState) -> Bool {
        lhs.preferences == rhs.preferences && lhs.workflows == rhs.workflows && lhs.snippets == rhs.snippets
            && lhs.clips == rhs.clips && lhs.usage == rhs.usage && lhs.knowledge == rhs.knowledge
            && lhs.selections == rhs.selections
    }
}

/// The parts of Jfred's saved state that are written separately.
public struct StateSections: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// `state.json`: preferences, workflows, snippets, knowledge, selections.
    public static let main = StateSections(rawValue: 1)
    /// `clips.json`: the clipboard history.
    public static let clips = StateSections(rawValue: 2)
    /// `usage.json`: usage events for the statistics pane.
    public static let usage = StateSections(rawValue: 4)
    public static let all: StateSections = [.main, .clips, .usage]
}

/// File names in the support folder. All live next to each other, so the
/// sync-folder option moves them together.
public enum StateFileName {
    public static let state = "state.json"
    public static let backup = "state.json.bak"
    public static let clips = "clips.json"
    public static let usage = "usage.json"
    /// A split file that could not be read is moved here instead of being
    /// overwritten.
    public static func unreadable(_ name: String) -> String { name + ".unreadable" }
}

/// `clips.json`.
public struct ClipHistoryFile: Codable, Equatable, Sendable {
    public var clips: [ClipItem]
    public init(clips: [ClipItem]) { self.clips = clips }
}

/// `usage.json`.
public struct UsageHistoryFile: Codable, Equatable, Sendable {
    public var usage: [UsageEvent]
    public init(usage: [UsageEvent]) { self.usage = usage }
}

/// What `StateStore.load` read.
public struct LoadedState: Sendable {
    /// `state.json`, or `state.json.bak` when the first could not be read. Its
    /// `clips` and `usage` are the ones below.
    public var state: DiskState?
    public var usedBackup: Bool
    /// The clipboard history: `clips.json`, plus any clips an older Jfred left
    /// in `state.json`.
    public var clips: [ClipItem]
    public var usage: [UsageEvent]
    /// Sections to write soon, because clips or usage still sit in
    /// `state.json` and need to move to their own files.
    public var sectionsToWrite: StateSections
    /// Split files that exist but could be neither read nor moved aside. They
    /// must not be overwritten; see `StateWriter.configure`.
    public var protectedSections: StateSections = []
}

/// Reads Jfred's saved state and moves the clipboard history and usage events
/// out of `state.json` into `clips.json` and `usage.json`, so that a copied
/// clip does not rewrite workflows and preferences.
public enum StateStore {
    public static let usageLimit = 20_000

    public static func load(directory: URL) -> LoadedState {
        let fileManager = FileManager.default
        var state = readState(directory.appendingPathComponent(StateFileName.state))
        var usedBackup = false
        if state == nil, let backup = readState(directory.appendingPathComponent(StateFileName.backup)) {
            state = backup
            usedBackup = true
        }
        let legacyClips = state?.clips ?? []
        let legacyUsage = state?.usage ?? []
        var toWrite: StateSections = []

        var protected: StateSections = []
        let clipsFile: ClipHistoryFile? = readSection(directory, StateFileName.clips, fileManager: fileManager, protecting: .clips, in: &protected)
        let clips: [ClipItem]
        if let clipsFile {
            // A state.json with clips was written by an older Jfred after the
            // split, so its clips are newer; a backup's are older.
            clips = mergeClips(clipsFile.clips, legacy: legacyClips, legacyIsNewer: !usedBackup)
        } else {
            clips = legacyClips
        }
        if !legacyClips.isEmpty { toWrite.formUnion([.clips, .main]) }

        let usageFile: UsageHistoryFile? = readSection(directory, StateFileName.usage, fileManager: fileManager, protecting: .usage, in: &protected)
        let usage: [UsageEvent]
        if let usageFile {
            usage = mergeUsage(usageFile.usage, legacy: legacyUsage)
        } else {
            usage = Array(legacyUsage.suffix(usageLimit))
        }
        if !legacyUsage.isEmpty { toWrite.formUnion([.usage, .main]) }

        state?.clips = clips
        state?.usage = usage
        return LoadedState(state: state, usedBackup: usedBackup, clips: clips, usage: usage, sectionsToWrite: toWrite, protectedSections: protected)
    }

    /// The history from `clips.json` with clips still in `state.json`. An older
    /// Jfred run after a downgrade starts from an empty history, so clips it
    /// recorded are newer and go first (`legacyIsNewer`). A clip in both
    /// places, left by a crash between the two writes, appears once.
    public static func mergeClips(_ current: [ClipItem], legacy: [ClipItem], legacyIsNewer: Bool = true) -> [ClipItem] {
        guard !legacy.isEmpty else { return current }
        var seen = Set<UUID>()
        var merged: [ClipItem] = []
        merged.reserveCapacity(current.count + legacy.count)
        for clip in legacyIsNewer ? legacy + current : current + legacy where seen.insert(clip.id).inserted {
            merged.append(clip)
        }
        return merged
    }

    /// Usage events from both places, oldest first, without duplicates, keeping
    /// the newest `usageLimit`.
    public static func mergeUsage(_ current: [UsageEvent], legacy: [UsageEvent]) -> [UsageEvent] {
        guard !legacy.isEmpty else { return Array(current.suffix(usageLimit)) }
        struct Key: Hashable {
            var time: Double
            var category: String
        }
        var seen = Set<Key>()
        var merged: [UsageEvent] = []
        for event in current + legacy where seen.insert(Key(time: event.date.timeIntervalSinceReferenceDate, category: event.category)).inserted {
            merged.append(event)
        }
        merged.sort { $0.date < $1.date }
        return Array(merged.suffix(usageLimit))
    }

    static func readState(_ url: URL) -> DiskState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DiskState.self, from: data)
    }

    /// Nil when the file is missing. A file that exists but cannot be read or
    /// decoded is moved aside so the next save does not overwrite it; when even
    /// that fails, `section` is added to `protected`.
    static func readSection<Section: Decodable>(_ directory: URL, _ name: String, fileManager: FileManager, protecting section: StateSections, in protected: inout StateSections) -> Section? {
        let url = directory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(Section.self, from: data) {
            return decoded
        }
        let aside = directory.appendingPathComponent(StateFileName.unreadable(name))
        try? fileManager.removeItem(at: aside)
        let line: String
        do {
            try fileManager.moveItem(at: url, to: aside)
            line = "Jfred: \(name) was unreadable; moved it to \(aside.lastPathComponent)\n"
        } catch {
            protected.formUnion(section)
            line = "Jfred: \(name) is unreadable and could not be moved; it will not be overwritten\n"
        }
        FileHandle.standardError.write(Data(line.utf8))
        return nil
    }
}

/// Encodes and writes Jfred's state on a serial background queue.
///
/// The main thread hands over a snapshot of value types; encoding and file IO
/// happen here. Snapshots submitted while a write runs are merged, newest
/// section wins, so a burst of changes produces at most one more write.
/// `flush()` waits for the write in progress and writes anything pending.
///
/// When `clips.json` or `usage.json` cannot be written, its data goes into
/// `state.json` instead, as older releases stored it, and every later write
/// retries the file. Loading moves it out again.
public final class StateWriter: @unchecked Sendable {
    /// The sections to write. A nil section is left as it is on disk.
    public struct Snapshot: Sendable {
        /// Written to `state.json` with empty `clips` and `usage`.
        public var main: DiskState?
        public var clips: [ClipItem]?
        public var usage: [UsageEvent]?

        public init(main: DiskState? = nil, clips: [ClipItem]? = nil, usage: [UsageEvent]? = nil) {
            self.main = main
            self.clips = clips
            self.usage = usage
        }

        public var isEmpty: Bool { main == nil && clips == nil && usage == nil }

        mutating func merge(_ newer: Snapshot) {
            if let main = newer.main { self.main = main }
            if let clips = newer.clips { self.clips = clips }
            if let usage = newer.usage { self.usage = usage }
        }
    }

    private let queue = DispatchQueue(label: "dev.jim.jfred.state", qos: .utility)
    private let lock = NSLock()
    private var pending: (snapshot: Snapshot, directory: URL)?

    // Only touched on `queue`.
    private var canOverwriteStateFile = true
    private var canReplaceStateBackup = false
    /// Split files never written this session.
    private var protectedSections: StateSections = []
    /// The newest `state.json` contents handed over, for rewriting it when a
    /// split file fails or recovers.
    private var lastMain: DiskState?
    private var lastDirectory: URL?
    /// Clips and usage whose own file could not be written.
    private var unwrittenClips: [ClipItem]?
    private var unwrittenUsage: [UsageEvent]?
    /// `state.json` on disk holds unwritten clips or usage.
    private var mainHoldsSplitData = false

    public init() {}

    /// The `state.json` safety rules from loading: an existing `state.json`
    /// that could not be read is not overwritten, and `state.json.bak` is only
    /// replaced once a good `state.json` has been read or written.
    /// `protectedSections` are split files that exist but could not be read;
    /// their data goes into `state.json` instead.
    public func configure(canOverwriteStateFile: Bool, canReplaceStateBackup: Bool, protectedSections: StateSections = []) {
        queue.sync {
            self.canOverwriteStateFile = canOverwriteStateFile
            self.canReplaceStateBackup = canReplaceStateBackup
            self.protectedSections = protectedSections.subtracting(.main)
        }
    }

    public func submit(_ snapshot: Snapshot, to directory: URL) {
        guard !snapshot.isEmpty else { return }
        lock.lock()
        if var current = pending, current.directory == directory {
            current.snapshot.merge(snapshot)
            pending = current
        } else if let current = pending {
            // The support folder moved: everything goes to the new place.
            var merged = current.snapshot
            merged.merge(snapshot)
            pending = (merged, directory)
        } else {
            pending = (snapshot, directory)
        }
        lock.unlock()
        queue.async { self.drain() }
    }

    /// Blocks until the write in progress and every submitted snapshot are on
    /// disk, and retries a split file that failed earlier.
    public func flush() {
        queue.sync {
            drain()
            if unwrittenClips != nil || unwrittenUsage != nil, let lastDirectory {
                write(Snapshot(), to: lastDirectory)
            }
        }
    }

    private func drain() {
        lock.lock()
        let next = pending
        pending = nil
        lock.unlock()
        guard let next else { return }
        write(next.snapshot, to: next.directory)
    }

    private func write(_ snapshot: Snapshot, to directory: URL) {
        lastDirectory = directory
        if let main = snapshot.main { lastMain = main }
        var rewriteMain = snapshot.main != nil
        // Split files first. A crash between the writes then leaves clips in
        // both places, which loading merges, never in neither.
        if let clips = snapshot.clips ?? unwrittenClips {
            let fresh = snapshot.clips != nil
            if writeSplit(.clips, ClipHistoryFile(clips: clips), named: StateFileName.clips, in: directory) {
                unwrittenClips = nil
            } else {
                unwrittenClips = clips
                // state.json must hold these clips until clips.json does.
                if fresh || !mainHoldsSplitData { rewriteMain = true }
            }
        }
        if let usage = snapshot.usage ?? unwrittenUsage {
            let fresh = snapshot.usage != nil
            if writeSplit(.usage, UsageHistoryFile(usage: usage), named: StateFileName.usage, in: directory) {
                unwrittenUsage = nil
            } else {
                unwrittenUsage = usage
                if fresh || !mainHoldsSplitData { rewriteMain = true }
            }
        }
        // A split file written at last: take its data out of state.json.
        if mainHoldsSplitData, unwrittenClips == nil, unwrittenUsage == nil { rewriteMain = true }
        guard rewriteMain, var main = lastMain else { return }
        main.clips = unwrittenClips ?? []
        main.usage = unwrittenUsage ?? []
        if writeMain(main, to: directory) {
            mainHoldsSplitData = unwrittenClips != nil || unwrittenUsage != nil
        }
    }

    private func writeSplit<Section: Encodable>(_ section: StateSections, _ value: Section, named name: String, in directory: URL) -> Bool {
        if protectedSections.contains(section) { return false }
        return Self.write(value, to: directory.appendingPathComponent(name))
    }

    /// True when `state.json` was written.
    @discardableResult
    private func writeMain(_ state: DiskState, to directory: URL) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(state) else { return false }
        let destination = directory.appendingPathComponent(StateFileName.state)
        let backup = directory.appendingPathComponent(StateFileName.backup)
        let current = try? Data(contentsOf: destination)
        if !canOverwriteStateFile, current != nil { return false }
        if StateFile.shouldUpdateBackup(current: current, newWorkflowCount: state.workflows.count, allowed: canReplaceStateBackup) {
            try? current?.write(to: backup, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        }
        let written = (try? data.write(to: destination, options: .atomic)) != nil
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        canReplaceStateBackup = true
        canOverwriteStateFile = true
        return written
    }

    private static func write<Section: Encodable>(_ section: Section, to url: URL) -> Bool {
        do {
            let data = try JSONEncoder().encode(section)
            try data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return true
        } catch {
            let line = "Jfred: could not write \(url.lastPathComponent): \(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(line.utf8))
            return false
        }
    }
}
