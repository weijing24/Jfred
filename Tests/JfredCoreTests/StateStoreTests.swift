import Foundation
import Testing
@testable import JfredCore

struct StateStoreTests {
    /// A fresh directory per test, removed by the caller.
    static func makeDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("jfred-state-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static let base = Date(timeIntervalSinceReferenceDate: 780_000_000)

    /// Decoded once, because decoding places workflow objects that sit at the
    /// origin; after that the state round-trips unchanged.
    static func sampleState(clips: [ClipItem] = [], usage: [UsageEvent] = []) -> DiskState {
        let state = rawSampleState(clips: clips, usage: usage)
        guard let data = try? JSONEncoder().encode(state),
              let decoded = try? JSONDecoder().decode(DiskState.self, from: data) else { return state }
        return decoded
    }

    static func rawSampleState(clips: [ClipItem], usage: [UsageEvent]) -> DiskState {
        var preferences = Preferences()
        preferences.clipboardLimit = 321
        return DiskState(
            preferences: preferences,
            workflows: [Workflow(name: "Alpha", keyword: "al", bundleID: "com.example.alpha")],
            snippets: [Snippet(name: "Sig", keyword: ";sig", text: "Regards")],
            clips: clips,
            usage: usage,
            knowledge: ["launcher.sync": "1"],
            selections: ["app:/Applications/Safari.app": SelectionStat(count: 3, lastSelected: base)]
        )
    }

    static func clips(_ count: Int, offset: Int = 0) -> [ClipItem] {
        (0..<count).map { index in
            ClipItem(
                text: "clip \(index + offset)",
                date: base.addingTimeInterval(Double(-(index + offset) * 60)),
                html: Data("<b>\(index)</b>".utf8),
                rtf: index == 0 ? Data("{\\rtf1 x}".utf8) : nil
            )
        }
    }

    static func usage(_ count: Int, from start: Double = 0) -> [UsageEvent] {
        (0..<count).map { index in
            UsageEvent(date: base.addingTimeInterval(start + Double(index) * 1.25), category: UsageEvent.categories[index % UsageEvent.categories.count])
        }
    }

    static func writeLegacy(_ state: DiskState, to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: directory.appendingPathComponent(StateFileName.state))
    }

    /// The decoder of Jfred releases before the split: `clips` and `usage`
    /// are required.
    struct StrictLegacyState: Decodable {
        var preferences: Preferences
        var snippets: [Snippet]
        var clips: [ClipItem]
        var usage: [UsageEvent]
        var knowledge: [String: String]
    }

    func save(_ writer: StateWriter, _ state: DiskState, sections: StateSections, to directory: URL) {
        var snapshot = StateWriter.Snapshot()
        if sections.contains(.main) { snapshot.main = state }
        if sections.contains(.clips) { snapshot.clips = state.clips }
        if sections.contains(.usage) { snapshot.usage = state.usage }
        writer.submit(snapshot, to: directory)
    }

    @Test func roundTripsEverySection() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = Self.sampleState(clips: Self.clips(5), usage: Self.usage(40))
        let writer = StateWriter()
        save(writer, state, sections: .all, to: directory)
        writer.flush()

        let loaded = StateStore.load(directory: directory)
        #expect(loaded.state == state)
        #expect(loaded.clips == state.clips)
        #expect(loaded.usage == state.usage)
        #expect(!loaded.usedBackup)
        #expect(loaded.sectionsToWrite.isEmpty)
    }

    @Test func stateFileKeepsEmptyClipsAndUsageForOlderReleases() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = StateWriter()
        save(writer, Self.sampleState(clips: Self.clips(3), usage: Self.usage(3)), sections: .all, to: directory)
        writer.flush()

        let data = try Data(contentsOf: directory.appendingPathComponent(StateFileName.state))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((object["clips"] as? [Any])?.isEmpty == true)
        #expect((object["usage"] as? [Any])?.isEmpty == true)
        let legacy = try JSONDecoder().decode(StrictLegacyState.self, from: data)
        #expect(legacy.clips.isEmpty)
        #expect(legacy.usage.isEmpty)
        #expect(legacy.snippets.map(\.keyword) == [";sig"])
        #expect(StateFile.isPlausible(data))
    }

    @Test func migratesClipsAndUsageOutOfStateFile() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = Self.sampleState(clips: Self.clips(4), usage: Self.usage(10))
        try Self.writeLegacy(state, to: directory)

        let loaded = StateStore.load(directory: directory)
        #expect(loaded.clips == state.clips)
        #expect(loaded.usage == state.usage)
        #expect(loaded.sectionsToWrite == .all)

        // What AppModel's first save writes.
        let writer = StateWriter()
        writer.configure(canOverwriteStateFile: true, canReplaceStateBackup: true)
        save(writer, try #require(loaded.state), sections: loaded.sectionsToWrite, to: directory)
        writer.flush()

        let fileManager = FileManager.default
        #expect(fileManager.fileExists(atPath: directory.appendingPathComponent(StateFileName.clips).path))
        #expect(fileManager.fileExists(atPath: directory.appendingPathComponent(StateFileName.usage).path))
        let slim = try JSONDecoder().decode(DiskState.self, from: Data(contentsOf: directory.appendingPathComponent(StateFileName.state)))
        #expect(slim.clips.isEmpty)
        #expect(slim.usage.isEmpty)
        // The old, full state.json became the backup.
        let backup = try JSONDecoder().decode(DiskState.self, from: Data(contentsOf: directory.appendingPathComponent(StateFileName.backup)))
        #expect(backup.clips == state.clips)

        let again = StateStore.load(directory: directory)
        #expect(again.clips == state.clips)
        #expect(again.usage == state.usage)
        #expect(again.state == state)
        #expect(again.sectionsToWrite.isEmpty)
    }

    @Test func noMigrationWhenStateFileHasNoClipsOrUsage() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Self.writeLegacy(Self.sampleState(), to: directory)
        let loaded = StateStore.load(directory: directory)
        #expect(loaded.sectionsToWrite.isEmpty)
        #expect(loaded.clips.isEmpty)
    }

    @Test func mergesWhatAnOlderReleaseRecordedAfterADowngrade() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let split = Self.clips(3, offset: 10)
        let splitUsage = Self.usage(5)
        let writer = StateWriter()
        save(writer, Self.sampleState(clips: split, usage: splitUsage), sections: .all, to: directory)
        writer.flush()

        // An older Jfred read the empty arrays and recorded new items in state.json.
        let newer = Self.clips(2)
        let newerUsage = Self.usage(3, from: 1_000)
        try Self.writeLegacy(Self.sampleState(clips: newer, usage: newerUsage), to: directory)

        let loaded = StateStore.load(directory: directory)
        #expect(loaded.clips.map(\.id) == (newer + split).map(\.id))
        #expect(loaded.usage == splitUsage + newerUsage)
        #expect(loaded.sectionsToWrite == .all)
    }

    @Test func aCrashBetweenWritesDoesNotDuplicate() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = Self.sampleState(clips: Self.clips(4), usage: Self.usage(6))
        try Self.writeLegacy(state, to: directory)
        // clips.json and usage.json written, state.json not yet slimmed.
        let writer = StateWriter()
        writer.submit(StateWriter.Snapshot(clips: state.clips, usage: state.usage), to: directory)
        writer.flush()

        let loaded = StateStore.load(directory: directory)
        #expect(loaded.clips == state.clips)
        #expect(loaded.usage == state.usage)
    }

    @Test func mergeUsageKeepsTheNewestEvents() {
        let current = Self.usage(StateStore.usageLimit)
        let legacy = Self.usage(10, from: 1_000_000)
        let merged = StateStore.mergeUsage(current, legacy: legacy)
        #expect(merged.count == StateStore.usageLimit)
        #expect(merged.last == legacy.last)
        #expect(merged.first == current[10])
    }

    @Test func backupClipsAreOlderThanTheSplitFile() {
        let current = Self.clips(2)
        let backup = Self.clips(2, offset: 5)
        #expect(StateStore.mergeClips(current, legacy: backup, legacyIsNewer: false).map(\.id) == (current + backup).map(\.id))
    }

    @Test func unreadableSplitFileIsMovedAside() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = Self.sampleState(clips: Self.clips(2))
        try Self.writeLegacy(state, to: directory)
        let clipsURL = directory.appendingPathComponent(StateFileName.clips)
        try Data("{not json".utf8).write(to: clipsURL)

        let loaded = StateStore.load(directory: directory)
        #expect(loaded.clips == state.clips)
        #expect(!FileManager.default.fileExists(atPath: clipsURL.path))
        let aside = directory.appendingPathComponent(StateFileName.unreadable(StateFileName.clips))
        #expect(try String(contentsOf: aside, encoding: .utf8) == "{not json")
    }

    @Test func aFailedClipsWriteKeepsClipsInStateFileUntilRetried() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = Self.sampleState(clips: Self.clips(4), usage: Self.usage(6))
        try Self.writeLegacy(state, to: directory)
        let loaded = StateStore.load(directory: directory)
        // A directory where clips.json should go makes the write fail.
        let clipsURL = directory.appendingPathComponent(StateFileName.clips)
        try FileManager.default.createDirectory(at: clipsURL, withIntermediateDirectories: false)
        let writer = StateWriter()
        writer.configure(canOverwriteStateFile: true, canReplaceStateBackup: true)
        save(writer, try #require(loaded.state), sections: loaded.sectionsToWrite, to: directory)
        writer.flush()
        let stateURL = directory.appendingPathComponent(StateFileName.state)
        var onDisk = try JSONDecoder().decode(DiskState.self, from: Data(contentsOf: stateURL))
        #expect(onDisk.clips == state.clips)
        #expect(onDisk.usage.isEmpty)

        // A later preferences save still keeps the clips in state.json.
        var changed = try #require(loaded.state)
        changed.knowledge["x"] = "y"
        writer.submit(StateWriter.Snapshot(main: changed), to: directory)
        writer.flush()
        onDisk = try JSONDecoder().decode(DiskState.self, from: Data(contentsOf: stateURL))
        #expect(onDisk.clips == state.clips)
        #expect(onDisk.knowledge["x"] == "y")

        // Once clips.json can be written, the next write moves them out.
        try FileManager.default.removeItem(at: clipsURL)
        writer.submit(StateWriter.Snapshot(usage: state.usage), to: directory)
        writer.flush()
        onDisk = try JSONDecoder().decode(DiskState.self, from: Data(contentsOf: stateURL))
        #expect(onDisk.clips.isEmpty)
        let again = StateStore.load(directory: directory)
        #expect(again.clips == state.clips)
        #expect(again.sectionsToWrite.isEmpty)
    }

    @Test func flushRetriesAFailedSplitWrite() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clipsURL = directory.appendingPathComponent(StateFileName.clips)
        try FileManager.default.createDirectory(at: clipsURL, withIntermediateDirectories: false)
        let writer = StateWriter()
        writer.submit(StateWriter.Snapshot(clips: Self.clips(2)), to: directory)
        writer.flush()
        try FileManager.default.removeItem(at: clipsURL)
        writer.flush()
        #expect(StateStore.load(directory: directory).clips.count == 2)
    }

    @Test func protectedSplitFilesAreNotOverwritten() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clipsURL = directory.appendingPathComponent(StateFileName.clips)
        try Data("keep me".utf8).write(to: clipsURL)
        let writer = StateWriter()
        writer.configure(canOverwriteStateFile: true, canReplaceStateBackup: false, protectedSections: .clips)
        let state = Self.sampleState(clips: Self.clips(3))
        save(writer, state, sections: .all, to: directory)
        writer.flush()
        #expect(try String(contentsOf: clipsURL, encoding: .utf8) == "keep me")
        let onDisk = try JSONDecoder().decode(DiskState.self, from: Data(contentsOf: directory.appendingPathComponent(StateFileName.state)))
        #expect(onDisk.clips == state.clips)
    }

    @Test func aSplitFileThatCannotBeReadIsMovedAside() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let usageURL = directory.appendingPathComponent(StateFileName.usage)
        let writer = StateWriter()
        writer.submit(StateWriter.Snapshot(usage: Self.usage(3)), to: directory)
        writer.flush()
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: usageURL.path)

        let loaded = StateStore.load(directory: directory)
        #expect(loaded.usage.isEmpty)
        #expect(loaded.protectedSections.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: usageURL.path))
        let aside = directory.appendingPathComponent(StateFileName.unreadable(StateFileName.usage))
        #expect(FileManager.default.fileExists(atPath: aside.path))
    }

    @Test func fallsBackToTheBackup() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = Self.sampleState(usage: Self.usage(2))
        let encoder = JSONEncoder()
        try encoder.encode(state).write(to: directory.appendingPathComponent(StateFileName.backup))
        try Data("garbage".utf8).write(to: directory.appendingPathComponent(StateFileName.state))

        let loaded = StateStore.load(directory: directory)
        #expect(loaded.usedBackup)
        #expect(loaded.state?.workflows.map(\.name) == ["Alpha"])
        #expect(loaded.usage == state.usage)
    }

    @Test func doesNotOverwriteAnUnreadableStateFile() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stateURL = directory.appendingPathComponent(StateFileName.state)
        try Data("garbage".utf8).write(to: stateURL)

        let writer = StateWriter()
        writer.configure(canOverwriteStateFile: false, canReplaceStateBackup: false)
        save(writer, Self.sampleState(clips: Self.clips(1)), sections: .all, to: directory)
        writer.flush()
        #expect(try String(contentsOf: stateURL, encoding: .utf8) == "garbage")
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(StateFileName.backup).path))
        // Clips have their own file and are still saved.
        #expect(StateStore.load(directory: directory).clips.count == 1)
    }

    @Test func backupIsNotReplacedByADegradedSave() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = StateWriter()
        writer.configure(canOverwriteStateFile: true, canReplaceStateBackup: true)
        let good = Self.sampleState()
        save(writer, good, sections: .main, to: directory)
        writer.flush()
        save(writer, good, sections: .main, to: directory)
        writer.flush()
        let backupURL = directory.appendingPathComponent(StateFileName.backup)
        let before = try Data(contentsOf: backupURL)

        var empty = good
        empty.workflows = []
        save(writer, empty, sections: .main, to: directory)
        writer.flush()
        #expect(try Data(contentsOf: backupURL) == before)
    }

    @Test func filesAreOwnerOnly() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = StateWriter()
        save(writer, Self.sampleState(clips: Self.clips(1), usage: Self.usage(1)), sections: .all, to: directory)
        writer.flush()
        for name in [StateFileName.state, StateFileName.clips, StateFileName.usage] {
            let attributes = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(name).path)
            #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600, "\(name)")
        }
    }

    @Test func aClipboardChangeDoesNotRewriteStateFile() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = StateWriter()
        let state = Self.sampleState(clips: Self.clips(1))
        save(writer, state, sections: .all, to: directory)
        writer.flush()
        let stateURL = directory.appendingPathComponent(StateFileName.state)
        let stamp = Date(timeIntervalSince1970: 1_000_000)
        try FileManager.default.setAttributes([.modificationDate: stamp], ofItemAtPath: stateURL.path)

        var changed = state
        changed.clips = Self.clips(2)
        save(writer, changed, sections: .clips, to: directory)
        writer.flush()
        let modified = try FileManager.default.attributesOfItem(atPath: stateURL.path)[.modificationDate] as? Date
        #expect(modified == stamp)
        #expect(StateStore.load(directory: directory).clips.count == 2)
    }

    @Test func burstsCoalesceAndFlushWritesTheNewest() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = StateWriter()
        for count in 1...50 {
            writer.submit(StateWriter.Snapshot(usage: Self.usage(count)), to: directory)
        }
        writer.submit(StateWriter.Snapshot(main: Self.sampleState()), to: directory)
        writer.flush()
        let loaded = StateStore.load(directory: directory)
        #expect(loaded.usage.count == 50)
        #expect(loaded.state?.snippets.count == 1)
    }

    @Test func snapshotMergeKeepsTheNewestOfEachSection() {
        var older = StateWriter.Snapshot(main: Self.sampleState(), clips: Self.clips(1))
        older.merge(StateWriter.Snapshot(clips: Self.clips(3), usage: Self.usage(2)))
        #expect(older.main != nil)
        #expect(older.clips?.count == 3)
        #expect(older.usage?.count == 2)
    }
}
