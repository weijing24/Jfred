import CoreServices
import Foundation
import JfredCore

/// Spotlight-backed file search for quick search and the `open`, `find`, `in`
/// and `tags` keywords.
///
/// One query runs at a time. A new request stops the running query, which then
/// returns at once, and requests that were waiting behind it are dropped, so the
/// newest request always runs next.
final class SpotlightSearch: @unchecked Sendable {
    static let shared = SpotlightSearch()

    /// Spotlight results read per name query. Spotlight evaluates the whole
    /// predicate whatever this is; reading a result's names costs well under a
    /// microsecond, so a large pool costs little and lets the best matches win.
    static let nameCandidateLimit = 2000
    /// Spotlight results read per contents or tags query.
    static let otherCandidateLimit = 1000
    /// Files returned per query: more than the launcher shows after ranking.
    static let hitLimit = 200
    /// Paths resolved per query. Each path costs about 8 µs.
    static let resolveLimit = 1500

    /// How long resolved scope roots are reused. Listing them reads the home
    /// folder and checks every child, which is too slow for every keystroke.
    static let scopeLifetime: TimeInterval = 30

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "dev.jim.jfred.spotlight", qos: .userInitiated)
    private var ticket = 0
    private var running: MDQuery?
    /// Only touched on `queue`.
    private var scopeCache: (key: [String], roots: [String], date: Date)?

    /// Files for `query`, or nil when a newer request or `cancel()` superseded it.
    func search(_ query: FileQuery, preferences: Preferences) async -> [FileHit]? {
        let mine = supersede()
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.run(query, preferences: preferences, ticket: mine))
            }
        }
    }

    /// Stops the running query and drops waiting ones.
    func cancel() {
        _ = supersede()
    }

    private func supersede() -> Int {
        lock.lock()
        defer { lock.unlock() }
        ticket += 1
        // Stopping returns a synchronous MDQueryExecute on the worker at once.
        // A query stopped before it starts executes as a no-op.
        if let running { MDQueryStop(running) }
        return ticket
    }

    private func isCurrent(_ mine: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return mine == ticket
    }

    private func run(_ request: FileQuery, preferences: Preferences, ticket mine: Int) -> [FileHit]? {
        guard isCurrent(mine) else { return nil }
        guard let predicate = SpotlightPredicate.make(for: request) else { return [] }
        let roots = scopeRoots(preferences)
        // An empty scope would search the whole Mac; no scope means no files.
        guard !roots.isEmpty else { return [] }
        let attributes = [kMDItemFSName!, kMDItemDisplayName!, kMDItemLastUsedDate!] as CFArray
        guard let query = MDQueryCreate(kCFAllocatorDefault, predicate as CFString, attributes, nil) else { return [] }
        MDQuerySetSearchScope(query, roots as CFArray, 0)
        MDQuerySetMaxCount(query, request.kind == .name ? Self.nameCandidateLimit : Self.otherCandidateLimit)

        lock.lock()
        guard mine == ticket else {
            lock.unlock()
            return nil
        }
        running = query
        lock.unlock()
        _ = MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue))
        lock.lock()
        running = nil
        let current = mine == ticket
        lock.unlock()
        defer { MDQueryStop(query) }
        guard current else { return nil }

        let count = MDQueryGetResultCount(query)
        var candidates: [FileCandidate] = []
        candidates.reserveCapacity(count)
        for index in 0..<count {
            let fileName = Self.string(query, kMDItemFSName, index) ?? ""
            let name = Self.string(query, kMDItemDisplayName, index) ?? fileName
            candidates.append(FileCandidate(name: name, fileName: fileName, lastUsed: Self.date(query, kMDItemLastUsedDate, index)))
        }
        let order: [Int]
        switch request.kind {
        case .name:
            order = Search.rankFileCandidates(query: request.text, candidates: candidates, preferences: preferences, now: Date())
        case .content, .tags:
            order = FileRanking.recentFirst(candidates)
        }

        let filter = FileScopeFilter(roots: roots)
        var hits: [FileHit] = []
        var resolved = 0
        for index in order {
            if hits.count >= Self.hitLimit || resolved >= Self.resolveLimit { break }
            resolved += 1
            guard let path = Self.path(query, index), !filter.excludes(path) else { continue }
            if Search.hidesFile(path, kind: request.kind, preferences: preferences) { continue }
            let candidate = candidates[index]
            let name = candidate.name.isEmpty ? (path as NSString).lastPathComponent : candidate.name
            hits.append(FileHit(path: path, name: name, lastUsed: candidate.lastUsed))
        }
        return isCurrent(mine) ? hits : nil
    }

    private func scopeRoots(_ preferences: Preferences) -> [String] {
        let key = [
            preferences.scopeApplications ? "apps" : "",
            preferences.scopeHome ? "home" : "",
            preferences.fileCustomHomeFolder,
        ] + preferences.scopePaths
        if let cache = scopeCache, cache.key == key, Date().timeIntervalSince(cache.date) < Self.scopeLifetime {
            return cache.roots
        }
        let roots = FileSearch.scopeRoots(preferences)
        scopeCache = (key, roots, Date())
        return roots
    }

    /// An attribute requested in `MDQueryCreate`; the query owns the value.
    private static func string(_ query: MDQuery, _ attribute: CFString, _ index: Int) -> String? {
        guard let raw = MDQueryGetAttributeValueOfResultAtIndex(query, attribute, index) else { return nil }
        let value = Unmanaged<CFTypeRef>.fromOpaque(raw).takeUnretainedValue()
        return value as? String
    }

    private static func date(_ query: MDQuery, _ attribute: CFString, _ index: Int) -> Date? {
        guard let raw = MDQueryGetAttributeValueOfResultAtIndex(query, attribute, index) else { return nil }
        let value = Unmanaged<CFTypeRef>.fromOpaque(raw).takeUnretainedValue()
        return value as? Date
    }

    /// Spotlight does not return kMDItemPath as a query value, so read it from the item.
    private static func path(_ query: MDQuery, _ index: Int) -> String? {
        guard let raw = MDQueryGetResultAtIndex(query, index) else { return nil }
        let item = Unmanaged<MDItem>.fromOpaque(UnsafeRawPointer(raw)).takeUnretainedValue()
        guard let path = MDItemCopyAttribute(item, kMDItemPath) as? String, path.hasPrefix("/") else { return nil }
        return path
    }
}
