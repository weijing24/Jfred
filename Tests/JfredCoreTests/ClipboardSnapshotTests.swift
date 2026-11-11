import Foundation
import Testing
@testable import JfredCore

struct ClipboardSnapshotTests {
    private let marker = "dev.jim.jfred.clipboard-origin"

    private func entry(_ type: String, _ text: String) -> ClipboardSnapshot.Entry {
        ClipboardSnapshot.Entry(type: type, data: Data(text.utf8))
    }

    /// Rich text, an image and two files: everything the old string-only
    /// restore threw away.
    private var richClipboard: ClipboardSnapshot {
        ClipboardSnapshot(items: [
            [entry("public.utf8-plain-text", "Hello"), entry("public.rtf", "{\\rtf1 Hello}"), entry("public.html", "<b>Hello</b>")],
            [entry("public.png", "PNG-BYTES"), entry("public.tiff", "TIFF-BYTES")],
            [entry("public.file-url", "file:///tmp/a.txt")],
            [entry("public.file-url", "file:///tmp/b.txt")],
        ])
    }

    @Test func restoreKeepsEveryItemAndTypeInOrder() throws {
        let restore = ClipboardRestore(saved: richClipboard, changeCount: 42)
        let items = try #require(restore.itemsToRestore(currentChangeCount: 42, marker: marker))
        #expect(items.count == 4)
        for (restored, original) in zip(items, richClipboard.items) {
            #expect(Array(restored.dropLast()) == original)
            #expect(restored.last == ClipboardSnapshot.Entry(type: marker, data: Data()))
        }
    }

    @Test func restoreIsSkippedWhenThePasteboardChangedAgain() {
        let restore = ClipboardRestore(saved: richClipboard, changeCount: 42)
        #expect(restore.itemsToRestore(currentChangeCount: 43, marker: marker) == nil)
        #expect(restore.itemsToRestore(currentChangeCount: 41, marker: marker) == nil)
    }

    @Test func emptyClipboardRestoresToEmpty() {
        let restore = ClipboardRestore(saved: ClipboardSnapshot(items: []), changeCount: 7)
        #expect(restore.itemsToRestore(currentChangeCount: 7, marker: marker) == [])
    }

    @Test func markerIsAddedOncePerItem() {
        let snapshot = ClipboardSnapshot(items: [
            [entry("public.utf8-plain-text", "from history"), ClipboardSnapshot.Entry(type: marker, data: Data())],
            [entry("public.png", "PNG")],
        ])
        let items = snapshot.markedItems(marker)
        #expect(items[0] == snapshot.items[0])
        #expect(items[1].map(\.type) == ["public.png", marker])
    }

    @Test func plainTextReadsTheFirstItemWithText() {
        #expect(richClipboard.plainText == "Hello")
        let imageFirst = ClipboardSnapshot(items: [[entry("public.png", "PNG")], [entry("public.utf8-plain-text", "caption")]])
        #expect(imageFirst.plainText == "caption")
        #expect(ClipboardSnapshot(items: [[entry("public.png", "PNG")]]).plainText == nil)
    }

    @Test func newWriteCapturesThePasteboard() {
        var captured = 0
        let saved = ClipboardRestore.contentsToSave(currentChangeCount: 10, pending: nil) {
            captured += 1
            return richClipboard
        }
        #expect(saved == richClipboard)
        #expect(captured == 1)
    }

    @Test func backToBackWritesKeepTheOriginalClipboard() {
        // The first paste's temporary text is still on the pasteboard: save
        // what it saved, not the temporary text.
        let first = ClipboardRestore(saved: richClipboard, changeCount: 10)
        var captured = 0
        let saved = ClipboardRestore.contentsToSave(currentChangeCount: 10, pending: first) {
            captured += 1
            return ClipboardSnapshot(items: [[entry("public.utf8-plain-text", "first snippet")]])
        }
        #expect(saved == richClipboard)
        #expect(captured == 0)
    }

    @Test func staleRestoreDoesNotShadowANewCopy() {
        // The user copied something after the earlier write; capture that.
        let stale = ClipboardRestore(saved: richClipboard, changeCount: 10)
        let copied = ClipboardSnapshot(items: [[entry("public.utf8-plain-text", "new copy")]])
        let saved = ClipboardRestore.contentsToSave(currentChangeCount: 12, pending: stale) { copied }
        #expect(saved == copied)
    }
}
