import Foundation

/// Every item on the pasteboard with all of its types and data, taken before
/// Jfred puts text there for a synthetic paste, so images, file lists and rich
/// text survive the paste.
public struct ClipboardSnapshot: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public var type: String
        public var data: Data

        public init(type: String, data: Data) {
            self.type = type
            self.data = data
        }
    }

    /// One array of entries per pasteboard item, in pasteboard order.
    public var items: [[Entry]]

    public init(items: [[Entry]]) {
        self.items = items
    }

    /// UTF-8 plain text of the first item that has any, as `{clipboard}` reads it.
    public var plainText: String? {
        for entries in items {
            if let entry = entries.first(where: { $0.type == "public.utf8-plain-text" }) {
                return String(data: entry.data, encoding: .utf8)
            }
        }
        return nil
    }

    /// The items to write back. Each also carries `marker`, the type that tells
    /// clipboard history the write is Jfred's own.
    public func markedItems(_ marker: String) -> [[Entry]] {
        items.map { entries in
            entries.contains { $0.type == marker } ? entries : entries + [Entry(type: marker, data: Data())]
        }
    }
}

/// A temporary pasteboard write that should be undone once the paste lands.
public struct ClipboardRestore: Equatable, Sendable {
    /// What the pasteboard held before the temporary write.
    public var saved: ClipboardSnapshot
    /// The pasteboard change count right after the temporary write.
    public var changeCount: Int

    public init(saved: ClipboardSnapshot, changeCount: Int) {
        self.saved = saved
        self.changeCount = changeCount
    }

    /// The items to put back, or nil when something else wrote to the
    /// pasteboard after the temporary write. A copy the user made in the
    /// meantime is never overwritten.
    public func itemsToRestore(currentChangeCount: Int, marker: String) -> [[ClipboardSnapshot.Entry]]? {
        guard currentChangeCount == changeCount else { return nil }
        return saved.markedItems(marker)
    }

    /// What a new temporary write should save. When the pasteboard still holds
    /// an earlier temporary write that has not been restored yet (two pastes in
    /// quick succession), keep that write's saved contents instead of capturing
    /// the temporary text; otherwise capture the pasteboard now.
    public static func contentsToSave(
        currentChangeCount: Int,
        pending: ClipboardRestore?,
        capture: () -> ClipboardSnapshot
    ) -> ClipboardSnapshot {
        if let pending, pending.changeCount == currentChangeCount { return pending.saved }
        return capture()
    }
}
