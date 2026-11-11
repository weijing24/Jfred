import Testing
@testable import JfredCore

struct LRUCacheTests {
    @Test func evictsTheLeastRecentEntryPastTheCountLimit() {
        let cache = LRUCache<String, Int>(countLimit: 3)
        cache.setValue(1, for: "a")
        cache.setValue(2, for: "b")
        cache.setValue(3, for: "c")
        // Reading "a" makes "b" the least recent.
        #expect(cache.value(for: "a") == 1)
        cache.setValue(4, for: "d")
        #expect(cache.count == 3)
        #expect(cache.value(for: "b") == nil)
        #expect(cache.keysByRecency == ["c", "a", "d"])
    }

    @Test func evictsPastTheCostLimit() {
        let cache = LRUCache<String, Int>(countLimit: 10, costLimit: 100)
        cache.setValue(1, for: "a", cost: 40)
        cache.setValue(2, for: "b", cost: 40)
        cache.setValue(3, for: "c", cost: 40)
        #expect(cache.keysByRecency == ["b", "c"])
        #expect(cache.totalCost == 80)
    }

    @Test func keepsTheNewestEntryEvenWhenItAloneIsOverTheCostLimit() {
        let cache = LRUCache<String, Int>(countLimit: 10, costLimit: 100)
        cache.setValue(1, for: "small", cost: 10)
        cache.setValue(2, for: "huge", cost: 500)
        #expect(cache.keysByRecency == ["huge"])
        #expect(cache.totalCost == 500)
    }

    @Test func replacingAValueUpdatesCostAndRecency() {
        let cache = LRUCache<String, Int>(countLimit: 3, costLimit: 100)
        cache.setValue(1, for: "a", cost: 30)
        cache.setValue(2, for: "b", cost: 30)
        cache.setValue(9, for: "a", cost: 50)
        #expect(cache.keysByRecency == ["b", "a"])
        #expect(cache.totalCost == 80)
        #expect(cache.value(for: "a") == 9)
    }

    @Test func containsDoesNotChangeTheOrder() {
        let cache = LRUCache<String, Int>(countLimit: 2)
        cache.setValue(1, for: "a")
        cache.setValue(2, for: "b")
        #expect(cache.contains("a"))
        cache.setValue(3, for: "c")
        #expect(!cache.contains("a"))
    }

    @Test func removeAndRemoveAll() {
        let cache = LRUCache<Int, Int>(countLimit: 1000, costLimit: 10_000)
        for index in 0..<500 { cache.setValue(index, for: index, cost: 1) }
        cache.removeValue(for: 0)
        cache.removeValue(for: 499)
        #expect(cache.count == 498)
        #expect(cache.totalCost == 498)
        #expect(cache.keysByRecency.first == 1)
        #expect(cache.keysByRecency.last == 498)
        cache.removeAll()
        #expect(cache.count == 0)
        #expect(cache.totalCost == 0)
        cache.setValue(7, for: 7)
        #expect(cache.keysByRecency == [7])
    }
}
