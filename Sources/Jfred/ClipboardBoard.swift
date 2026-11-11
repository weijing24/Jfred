import AppKit
import Foundation
import JfredCore
import Vision

enum ClipboardBoard {
    static let origin = NSPasteboard.PasteboardType("dev.jim.jfred.clipboard-origin")

    struct Capture {
        var string: String?
        var html: Data?
        var rtf: Data?
        var image: Data?
        var imageType: String?
        var fileURLs: [URL]
    }

    private static let privateBundles: Set<String> = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.apple.Passbook",
        "com.apple.SecurityAgent",
        "com.apple.systempreferences",
    ]

    private static let privateNames: Set<String> = [
        "1Password", "1Password 7", "Keychain Access", "Passwords", "Wallet",
        "SecurityAgent", "System Settings", "System Preferences",
    ]

    static func isOwnWrite(_ board: NSPasteboard) -> Bool {
        (board.types ?? []).contains(origin)
    }

    static func shouldIgnore(app: NSRunningApplication?, extra: [String]) -> Bool {
        let bundle = app?.bundleIdentifier ?? ""
        let name = app?.localizedName ?? ""
        if privateBundles.contains(bundle) || privateNames.contains(name) { return true }
        return extra.contains { entry in
            entry.caseInsensitiveCompare(bundle) == .orderedSame || entry.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    static func capture(_ board: NSPasteboard) -> Capture {
        var capture = Capture(string: nil, html: nil, rtf: nil, image: nil, imageType: nil, fileURLs: [])
        let items = board.pasteboardItems ?? []
        if items.isEmpty {
            capture.string = board.string(forType: .string)
            capture.html = board.data(forType: .html)
            capture.rtf = board.data(forType: .rtf)
            if let png = board.data(forType: .png) {
                capture.image = png
                capture.imageType = "png"
            } else if let tiff = board.data(forType: .tiff) {
                capture.image = tiff
                capture.imageType = "tiff"
            }
        } else {
            for item in items {
                if capture.string == nil { capture.string = item.string(forType: .string) }
                if capture.html == nil { capture.html = item.data(forType: .html) }
                if capture.rtf == nil { capture.rtf = item.data(forType: .rtf) }
                if capture.image == nil, let png = item.data(forType: .png) {
                    capture.image = png
                    capture.imageType = "png"
                } else if capture.image == nil, let tiff = item.data(forType: .tiff) {
                    capture.image = tiff
                    capture.imageType = "tiff"
                }
            }
        }
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        capture.fileURLs = (board.readObjects(forClasses: [NSURL.self], options: options) as? [URL]) ?? []
        capture.html = bounded(capture.html)
        capture.rtf = bounded(capture.rtf)
        let cleaned = ClipboardText.sanitized(capture.string ?? "")
        if cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            capture.string = plainText(html: capture.html, rtf: capture.rtf)
        } else {
            capture.string = cleaned
        }
        return capture
    }

    static func write(_ clip: ClipItem, to board: NSPasteboard) {
        board.clearContents()
        switch clip.kind {
        case "image":
            guard let path = clip.imageFile, let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
            let item = NSPasteboardItem()
            item.setData(data, forType: clip.imageType == "tiff" ? .tiff : .png)
            item.setData(Data(), forType: origin)
            board.writeObjects([item])
        case "file":
            let urls = (clip.filePaths ?? []).map { URL(fileURLWithPath: $0) as NSURL }
            guard !urls.isEmpty else { return }
            board.writeObjects(urls)
            board.setData(Data(), forType: origin)
        default:
            let item = NSPasteboardItem()
            item.setString(clip.text, forType: .string)
            if let html = clip.html { item.setData(html, forType: .html) }
            if let rtf = clip.rtf { item.setData(rtf, forType: .rtf) }
            item.setData(Data(), forType: origin)
            board.writeObjects([item])
        }
    }

    static func sameImage(_ data: Data, as clip: ClipItem?) -> Bool {
        guard clip?.kind == "image", let path = clip?.imageFile,
              let existing = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return false }
        return existing == data
    }

    static func saveImage(_ data: Data, type: String, directory: URL) -> String? {
        let ext = type == "tiff" ? "tiff" : "png"
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let url = directory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        do {
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return url.path
        } catch {
            return nil
        }
    }

    nonisolated static func recognizeText(in data: Data) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(data: data, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        let text = request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return nil }
        return ClipboardText.sanitized(text)
    }

    private static func bounded(_ data: Data?) -> Data? {
        guard let data, !data.isEmpty, data.count <= 2_000_000 else { return nil }
        return data
    }

    private static func plainText(html: Data?, rtf: Data?) -> String? {
        if let rtf, let string = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            let plain = ClipboardText.sanitized(string.string).trimmingCharacters(in: .whitespacesAndNewlines)
            if !plain.isEmpty { return plain }
        }
        if let html, let string = attributedHTML(html) {
            let plain = ClipboardText.sanitized(string.string).trimmingCharacters(in: .whitespacesAndNewlines)
            if !plain.isEmpty { return plain }
        }
        return nil
    }

    private static func attributedHTML(_ data: Data) -> NSAttributedString? {
        try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil)
    }
}

/// Text Jfred puts on the general pasteboard only to send a synthetic ⌘V, and
/// putting the user's clipboard back afterwards. Main thread only.
@MainActor
enum TemporaryClipboard {
    /// The last temporary write still waiting to be restored.
    private static var pending: ClipboardRestore?

    /// Replace the pasteboard with `text`. With `restoring`, every item and
    /// type on the pasteboard is saved first, and the write carries
    /// `ClipboardBoard.origin` so clipboard history skips it. Pass the result
    /// to `restore(_:)` once the paste has landed.
    static func write(_ text: String, restoring: Bool) -> ClipboardRestore? {
        let board = NSPasteboard.general
        let saved: ClipboardSnapshot? = restoring
            ? ClipboardRestore.contentsToSave(currentChangeCount: board.changeCount, pending: pending) { snapshot(board) }
            : nil
        board.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        if restoring { item.setData(Data(), forType: ClipboardBoard.origin) }
        board.writeObjects([item])
        guard let saved else {
            pending = nil
            return nil
        }
        let restore = ClipboardRestore(saved: saved, changeCount: board.changeCount)
        pending = restore
        return restore
    }

    /// The user's plain-text clipboard for `{clipboard}`. While an earlier
    /// temporary write is still on the pasteboard, that is the text it saved.
    static func userText() -> String? {
        let board = NSPasteboard.general
        if let pending, pending.changeCount == board.changeCount { return pending.saved.plainText }
        return board.string(forType: .string)
    }

    /// Put the saved contents back, marked as Jfred's own write. Does nothing
    /// when anything else wrote to the pasteboard after the temporary text.
    static func restore(_ restore: ClipboardRestore) {
        let board = NSPasteboard.general
        if pending?.changeCount == restore.changeCount { pending = nil }
        guard let items = restore.itemsToRestore(currentChangeCount: board.changeCount, marker: ClipboardBoard.origin.rawValue) else { return }
        board.clearContents()
        let objects = items.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for entry in entries {
                item.setData(entry.data, forType: NSPasteboard.PasteboardType(entry.type))
            }
            return item
        }
        if !objects.isEmpty { board.writeObjects(objects) }
    }

    /// Every item on `board` with all of its types and their data.
    static func snapshot(_ board: NSPasteboard) -> ClipboardSnapshot {
        let items = (board.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in
                item.data(forType: type).map { ClipboardSnapshot.Entry(type: type.rawValue, data: $0) }
            }
        }
        return ClipboardSnapshot(items: items.filter { !$0.isEmpty })
    }
}
