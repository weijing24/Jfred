import Foundation

/// A least-recently-used cache bounded by entry count and by total cost.
/// Reading or storing an entry makes it the most recent; storing past either
/// limit evicts the least recent entries. Not thread-safe: use it from one
/// thread or actor.
public final class LRUCache<Key: Hashable, Value> {
    private final class Node {
        let key: Key
        var value: Value
        var cost: Int
        var newer: Node?
        weak var older: Node?

        init(key: Key, value: Value, cost: Int) {
            self.key = key
            self.value = value
            self.cost = cost
        }
    }

    public let countLimit: Int
    public let costLimit: Int
    public private(set) var totalCost = 0

    private var nodes: [Key: Node] = [:]
    /// Least recent entry. Each node owns the next newer one.
    private var oldest: Node?
    /// Most recent entry.
    private weak var newest: Node?

    public init(countLimit: Int, costLimit: Int = .max) {
        self.countLimit = max(1, countLimit)
        self.costLimit = max(1, costLimit)
    }

    public var count: Int { nodes.count }

    /// The value for `key`, which becomes the most recent entry.
    public func value(for key: Key) -> Value? {
        guard let node = nodes[key] else { return nil }
        moveToNewest(node)
        return node.value
    }

    /// True when `key` is stored. Does not change the order.
    public func contains(_ key: Key) -> Bool {
        nodes[key] != nil
    }

    public func setValue(_ value: Value, for key: Key, cost: Int = 0) {
        let cost = max(0, cost)
        if let node = nodes[key] {
            totalCost += cost - node.cost
            node.value = value
            node.cost = cost
            moveToNewest(node)
        } else {
            let node = Node(key: key, value: value, cost: cost)
            nodes[key] = node
            totalCost += cost
            append(node)
        }
        evict()
    }

    public func removeValue(for key: Key) {
        guard let node = nodes.removeValue(forKey: key) else { return }
        totalCost -= node.cost
        unlink(node)
    }

    public func removeAll() {
        // Break the chain iteratively; a long chain of owning references would
        // otherwise be released recursively.
        while let node = oldest {
            oldest = node.newer
            node.newer = nil
        }
        nodes.removeAll()
        newest = nil
        totalCost = 0
    }

    /// Keys from least to most recent.
    public var keysByRecency: [Key] {
        var keys: [Key] = []
        var node = oldest
        while let current = node {
            keys.append(current.key)
            node = current.newer
        }
        return keys
    }

    private func evict() {
        // Always keep the newest entry, even when it alone exceeds the cost limit.
        while nodes.count > countLimit || (totalCost > costLimit && nodes.count > 1) {
            guard let node = oldest else { break }
            nodes.removeValue(forKey: node.key)
            totalCost -= node.cost
            unlink(node)
        }
    }

    private func append(_ node: Node) {
        node.older = newest
        node.newer = nil
        if let newest {
            newest.newer = node
        } else {
            oldest = node
        }
        newest = node
    }

    private func unlink(_ node: Node) {
        let older = node.older
        let newer = node.newer
        if let older {
            older.newer = newer
        } else {
            oldest = newer
        }
        if let newer {
            newer.older = older
        } else {
            newest = older
        }
        node.older = nil
        node.newer = nil
    }

    private func moveToNewest(_ node: Node) {
        guard newest !== node else { return }
        unlink(node)
        append(node)
    }
}
