import AppKit
import AlfredCore
import SwiftUI

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class LauncherController {
    let model: AppModel
    private var panel: LauncherPanel?
    private var largePanel: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var pinnedTop: CGFloat?
    private var outsideDrag: (mouse: NSPoint, origin: NSPoint)?
    private var localDrag: (mouse: NSPoint, origin: NSPoint)?

    init(model: AppModel) { self.model = model }

    func install() {
        let panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 120),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        let host = NSHostingView(rootView: LauncherRoot(model: model))
        host.frame = panel.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        self.panel = panel
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] note in
            let maxY = (note.object as? NSWindow)?.frame.maxY
            MainActor.assumeIsolated {
                if let maxY { self?.pinnedTop = maxY }
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.globalMouse(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.localMouse(event) ?? event
        }
    }

    func show() {
        guard let panel else { return }
        if pinnedTop == nil { placeInitially() }
        layout()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() { panel?.orderOut(nil) }

    func layout() {
        guard let panel else { return }
        let rows = CGFloat(model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : max(model.results.count, 1))
        let buffer: CGFloat = model.fileBuffer.isEmpty ? 0 : 34
        let height = 96 + buffer + rows * 62 + (rows > 0 ? 12 : 8)
        let width: CGFloat = 760
        var frame = panel.frame
        let top = pinnedTop ?? frame.maxY
        frame.size = NSSize(width: width, height: height)
        frame.origin.y = top - height
        panel.setFrame(frame, display: true)
        pinnedTop = panel.frame.maxY
    }

    func showLarge(_ text: String, size: Double, font: String) {
        let panel = NSPanel(
            contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: LargeTypeView(text: text, size: size, fontName: font) { [weak self] in
            self?.largePanel?.orderOut(nil)
            self?.largePanel = nil
        })
        panel.contentView = host
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            panel.setFrame(screen.frame, display: true)
        }
        panel.makeKeyAndOrderFront(nil)
        largePanel = panel
    }

    private func placeInitially() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        var frame = panel.frame
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.maxY - 150 - frame.height
        panel.setFrame(frame, display: false)
        pinnedTop = panel.frame.maxY
    }

    private func globalMouse(_ event: NSEvent) {
        guard model.launcherVisible, let panel else { return }
        let loc = NSEvent.mouseLocation
        switch event.type {
        case .leftMouseDown:
            if panel.frame.contains(loc) {
                outsideDrag = (loc, panel.frame.origin)
            } else {
                outsideDrag = nil
                model.hideLauncher(reactivate: false)
            }
        case .rightMouseDown:
            if !panel.frame.contains(loc) {
                model.hideLauncher(reactivate: false)
            }
        case .leftMouseDragged:
            guard let drag = outsideDrag else { return }
            panel.setFrameOrigin(NSPoint(x: drag.origin.x + loc.x - drag.mouse.x, y: drag.origin.y + loc.y - drag.mouse.y))
            pinnedTop = panel.frame.maxY
        case .leftMouseUp:
            outsideDrag = nil
        default:
            break
        }
    }

    private func localMouse(_ event: NSEvent) -> NSEvent? {
        guard let panel, event.window === panel else { return event }
        let loc = NSEvent.mouseLocation
        switch event.type {
        case .leftMouseDown:
            localDrag = (loc, panel.frame.origin)
            return event
        case .leftMouseDragged:
            guard let drag = localDrag else { return event }
            let dx = loc.x - drag.mouse.x
            let dy = loc.y - drag.mouse.y
            guard hypot(dx, dy) >= 3 else { return event }
            panel.setFrameOrigin(NSPoint(x: drag.origin.x + dx, y: drag.origin.y + dy))
            pinnedTop = panel.frame.maxY
            return nil
        case .leftMouseUp:
            localDrag = nil
            return event
        default:
            return event
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard model.launcherVisible, panel?.isKeyWindow == true else { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.keyCode {
        case 125:
            model.move(1)
            return nil
        case 126:
            if flags.contains(.option) {
                model.addBuffer()
                return nil
            }
            model.move(-1)
            return nil
        case 36, 76:
            model.commit(flags: flags)
            return nil
        case 53:
            model.hideLauncher(reactivate: true)
            return nil
        case 48:
            model.completeSelected()
            return nil
        default:
            break
        }
        if flags.contains(.command), let chars = event.charactersIgnoringModifiers?.lowercased() {
            if let number = Int(chars), (1...9).contains(number) {
                model.commitIndex(number - 1)
                return nil
            }
            if chars == "c" { model.copySelected(); return nil }
            if chars == "l" { model.largeTypeSelected(); return nil }
            if chars == "y" { model.quickLookSelected(); return nil }
        }
        return event
    }
}

struct LauncherRoot: View {
    var model: AppModel

    var body: some View {
        let theme = LauncherTheme.by(id: model.preferences.themeID)
        VStack(alignment: .leading, spacing: 0) {
            QueryField(
                text: model.query,
                token: model.focusToken,
                font: queryFont(theme),
                color: NSColor(theme.query),
                onChange: { model.query = $0 }
            )
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 8)
            if !model.fileBuffer.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.fileBuffer) { item in
                            Text(item.title)
                                .font(.system(size: 11))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.25)))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 6)
                }
            }
            if !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: 2) {
                    if model.results.isEmpty {
                        Text("No matches")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.subtitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, item in
                            LauncherRow(item: item, index: index, selected: index == model.selection, theme: theme)
                                .contentShape(Rectangle())
                                .onTapGesture { model.commitIndex(index) }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                .fill(theme.background)
                .background {
                    if theme.material != nil {
                        RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                            .fill(theme.material ?? .ultraThin)
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.28), radius: 28, y: 16)
        .onChange(of: model.query) { _, _ in model.scheduleSearch() }
    }

    private func queryFont(_ theme: LauncherTheme) -> NSFont {
        if let name = theme.fontName, let font = NSFont(name: name, size: theme.querySize) {
            return font
        }
        return NSFont.systemFont(ofSize: theme.querySize)
    }
}

struct QueryField: NSViewRepresentable {
    var text: String
    var token: Int
    var font: NSFont
    var color: NSColor
    var onChange: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = font
        field.textColor = color
        field.delegate = context.coordinator
        field.placeholderString = "Search"
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.onChange = onChange
        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }
        field.font = font
        field.textColor = color
        if context.coordinator.token != token {
            context.coordinator.token = token
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var onChange: (String) -> Void
        var token = -1
        init(onChange: @escaping (String) -> Void) { self.onChange = onChange }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            onChange(field.stringValue)
        }
    }
}

struct LauncherRow: View {
    var item: SearchResult
    var index: Int
    var selected: Bool
    var theme: LauncherTheme

    private var shortcut: String {
        if index == 0 && selected { return "↩" }
        guard index < 9 else { return "" }
        return "⌘\(index + 1)"
    }

    var body: some View {
        HStack(spacing: 12) {
            ResultIcon(icon: item.icon, tint: selected ? theme.selectedTitle : theme.title)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(theme.font(size: 16, weight: .medium))
                    .foregroundStyle(selected ? theme.selectedTitle : theme.title)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(selected ? theme.selectedSubtitle : theme.subtitle)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(shortcut)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? theme.selectedSubtitle : theme.subtitle)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 58, maxHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? theme.selected : Color.clear)
        )
    }
}

struct LargeTypeView: View {
    var text: String
    var size: Double
    var fontName: String
    var dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            Text(text)
                .font(fontName == "System" ? .system(size: size, weight: .semibold) : .custom(fontName, size: size))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.2)
                .padding(48)
                .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
        }
        .onTapGesture { dismiss() }
        .onExitCommand { dismiss() }
    }
}

struct PreviewLauncher: View {
    var theme: LauncherTheme
    private let rows: [(String, String, String)] = [
        ("Computer", "Open Computer in Finder", "symbol:desktopcomputer"),
        ("Mission Control", "/Applications/Mission Control.app", "symbol:squares.below.rectangle"),
        ("Contacts", "/Applications/Contacts.app", "symbol:person.crop.circle"),
        ("Digital Colour Meter", "/Applications/Utilities/Digital Color Meter.app", "symbol:eyedropper"),
        ("Console", "/Applications/Utilities/Console.app", "symbol:terminal"),
        ("ColorSync Utility", "/Applications/Utilities/ColorSync Utility.app", "symbol:circle.hexagongrid"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Co")
                .font(theme.font(size: theme.querySize))
                .foregroundStyle(theme.query)
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 6)
            VStack(spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 12) {
                        Image(systemName: String(row.2.dropFirst("symbol:".count)))
                            .frame(width: 28)
                            .foregroundStyle(index == 0 ? theme.selectedTitle : theme.title)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.0).font(theme.font(size: 16, weight: .medium)).foregroundStyle(index == 0 ? theme.selectedTitle : theme.title)
                            Text(row.1).font(.system(size: 12)).foregroundStyle(index == 0 ? theme.selectedSubtitle : theme.subtitle).lineLimit(1)
                        }
                        Spacer()
                        Text(index == 0 ? "↩" : "⌘\(index + 1)")
                            .foregroundStyle(index == 0 ? theme.selectedSubtitle : theme.subtitle)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 10).fill(index == 0 ? theme.selected : Color.clear))
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .frame(width: 640)
        .background {
            RoundedRectangle(cornerRadius: theme.radius, style: .continuous).fill(theme.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
    }
}
