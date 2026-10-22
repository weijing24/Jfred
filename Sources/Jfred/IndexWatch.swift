import AppKit
import CoreServices
import Foundation
import JfredCore

struct IndexedFile: Sendable {
    var path: String
    var name: String
    var isFolder: Bool
}

final class FileIndex: @unchecked Sendable {
    static let shared = FileIndex()
    private let lock = NSLock()
    private var files: [String: IndexedFile] = [:]
    private var ready = false

    var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return ready
    }

    func replaceAll(_ items: [IndexedFile]) {
        lock.lock()
        files = Dictionary(items.map { ($0.path, $0) }, uniquingKeysWith: { _, latest in latest })
        ready = true
        lock.unlock()
    }

    func upsert(_ item: IndexedFile) {
        lock.lock()
        files[item.path] = item
        ready = true
        lock.unlock()
    }

    func removeTree(_ path: String) {
        lock.lock()
        files.removeValue(forKey: path)
        let prefix = path.hasSuffix("/") ? path : path + "/"
        for key in Array(files.keys) where key.hasPrefix(prefix) {
            files.removeValue(forKey: key)
        }
        lock.unlock()
    }

    func search(query: String, limit: Int) -> [AppRecord] {
        guard !fold(query).isEmpty else { return [] }
        lock.lock()
        let snapshot = Array(files.values)
        lock.unlock()
        var hits: [(AppRecord, FieldMatch)] = []
        for file in snapshot {
            guard let match = fieldMatch(query: query, target: file.name), match.tier <= 3 else { continue }
            hits.append((AppRecord(id: file.path, name: file.name, path: file.path), match))
        }
        hits.sort { lhs, rhs in
            if lhs.1.tier != rhs.1.tier { return lhs.1.tier < rhs.1.tier }
            if lhs.1.score != rhs.1.score { return lhs.1.score > rhs.1.score }
            return lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending
        }
        return hits.prefix(limit).map(\.0)
    }
}

enum FileCatalog {
    static let limit = 60_000

    static func collect(preferences: Preferences) -> [IndexedFile] {
        var items: [IndexedFile] = []
        for root in FileSearch.scopeRoots(preferences) {
            walk(URL(fileURLWithPath: root), into: &items)
            if items.count >= limit { break }
        }
        return items
    }

    static func walk(_ root: URL, into items: inout [IndexedFile]) {
        guard items.count < limit else { return }
        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return }
        while let url = enumerator.nextObject() as? URL {
            if items.count >= limit { return }
            let name = url.lastPathComponent
            if name == "node_modules" || name == ".git" || name == ".build" || name == "DerivedData" || name == "Pods" {
                enumerator.skipDescendants()
                continue
            }
            let ext = url.pathExtension.lowercased()
            if ext == "photoslibrary" || ext == "musiclibrary" || ext == "tvlibrary" || ext == "aplibrary" {
                enumerator.skipDescendants()
                continue
            }
            if ext == "app" || ext == "prefpane" {
                enumerator.skipDescendants()
                continue
            }
            let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            items.append(IndexedFile(path: url.path, name: name, isFolder: isFolder))
        }
    }
}

final class PathWatch: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private let queue: DispatchQueue
    var handler: (([String], [FSEventStreamEventFlags]) -> Void)?

    init(label: String) {
        queue = DispatchQueue(label: label, qos: .utility)
    }

    func start(paths: [String], latency: CFTimeInterval) {
        stop()
        let existing = paths.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existing.isEmpty else { return }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
        )
        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, numEvents, eventPaths, eventFlags, _ in
                guard let info else { return }
                let watch = Unmanaged<PathWatch>.fromOpaque(info).takeUnretainedValue()
                let array = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as NSArray
                guard let paths = array as? [String] else { return }
                let flags = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))
                watch.handler?(paths, flags)
            },
            &context,
            existing as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        )
        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}

final class IndexWatch: @unchecked Sendable {
    static let shared = IndexWatch()
    private let apps = PathWatch(label: "dev.jim.jfred.apps")
    private let files = PathWatch(label: "dev.jim.jfred.files")
    private var appDebounce: DispatchWorkItem?
    private var wakeObserver: NSObjectProtocol?
    private var preferences = Preferences()
    private var onApps: (() -> Void)?

    func start(preferences: Preferences, onApps: @escaping () -> Void) {
        self.onApps = onApps
        self.preferences = preferences
        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.restartAfterWake()
            }
        }
        restartApps(preferences)
        restartFiles(preferences)
    }

    func restartApps(_ preferences: Preferences) {
        self.preferences = preferences
        let paths = AppIndexer.watchPaths(preferences: preferences)
        apps.handler = { [weak self] _, _ in self?.scheduleAppRescan() }
        apps.start(paths: paths, latency: 1)
    }

    func restartFiles(_ preferences: Preferences) {
        self.preferences = preferences
        let paths = FileSearch.scopeRoots(preferences)
        files.handler = { [weak self] paths, flags in
            self?.applyFileEvents(paths: paths, flags: flags)
        }
        files.start(paths: paths, latency: 0.5)
        let snapshot = preferences
        DispatchQueue.global(qos: .utility).async {
            FileIndex.shared.replaceAll(FileCatalog.collect(preferences: snapshot))
        }
    }

    private func restartAfterWake() {
        apps.stop()
        files.stop()
        restartApps(preferences)
        restartFiles(preferences)
    }

    private func scheduleAppRescan() {
        appDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async { self?.onApps?() }
        }
        appDebounce = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func applyFileEvents(paths: [String], flags: [FSEventStreamEventFlags]) {
        let fileManager = FileManager.default
        for (path, flag) in zip(paths, flags) {
            let name = (path as NSString).lastPathComponent
            if name.hasPrefix(".") || path.contains(".app/") || path.contains(".prefPane/") || path.contains(".prefpane/") {
                continue
            }
            let removed = flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0
            let renamed = flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0
            let mustScan = flag & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs) != 0
            if removed || (renamed && !fileManager.fileExists(atPath: path)) {
                FileIndex.shared.removeTree(path)
                continue
            }
            var isFolder: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isFolder) else {
                FileIndex.shared.removeTree(path)
                continue
            }
            let ext = (path as NSString).pathExtension.lowercased()
            if ext == "app" || ext == "prefpane" { continue }
            FileIndex.shared.upsert(IndexedFile(path: path, name: name, isFolder: isFolder.boolValue))
            if mustScan && isFolder.boolValue {
                var found: [IndexedFile] = []
                FileCatalog.walk(URL(fileURLWithPath: path), into: &found)
                for item in found { FileIndex.shared.upsert(item) }
            }
        }
    }
}
