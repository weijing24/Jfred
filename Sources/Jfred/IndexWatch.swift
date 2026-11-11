import AppKit
import CoreServices
import Foundation
import JfredCore

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

/// Watches the application folders and rescans apps when they change. File
/// search needs no index of its own: Spotlight keeps it current.
final class IndexWatch: @unchecked Sendable {
    static let shared = IndexWatch()
    private let apps = PathWatch(label: "dev.jim.jfred.apps")
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
    }

    func restartApps(_ preferences: Preferences) {
        self.preferences = preferences
        let paths = AppIndexer.watchPaths(preferences: preferences)
        apps.handler = { [weak self] _, _ in self?.scheduleAppRescan() }
        apps.start(paths: paths, latency: 1)
    }

    private func restartAfterWake() {
        apps.stop()
        restartApps(preferences)
    }

    private func scheduleAppRescan() {
        appDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async { self?.onApps?() }
        }
        appDebounce = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1, execute: work)
    }
}
