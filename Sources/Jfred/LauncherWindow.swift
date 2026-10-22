import AppKit
import JfredCore
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
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
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
        let filled = model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : max(model.results.count, 1)
        let rows = CGFloat(min(filled, LauncherMetrics.visibleRows))
        let buffer: CGFloat = model.fileBuffer.isEmpty ? 0 : 34
        let header: CGFloat = rows > 0 ? 80 : LauncherMetrics.queryHeight
        let height = header + buffer + rows * LauncherMetrics.rowStride + (rows > 0 ? 12 : 0)
        let width: CGFloat = 760
        var frame = panel.frame
        let top = pinnedTop ?? frame.maxY
        frame.size = NSSize(width: width, height: height)
        frame.origin.y = top - height
        if let screen = panel.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            if frame.minY < visible.minY {
                frame.origin.y = max(visible.minY, visible.maxY - frame.height)
            }
        }
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
        guard let panel else { return event }
        if model.launcherVisible, event.type == .leftMouseDown || event.type == .rightMouseDown {
            let inside = event.window === panel && panel.frame.contains(NSEvent.mouseLocation)
            if !inside {
                model.hideLauncher(reactivate: false)
                return event
            }
        }
        guard event.window === panel else { return event }
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
        let searching = !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        VStack(alignment: .leading, spacing: 0) {
            QueryField(
                text: model.query,
                token: model.focusToken,
                font: NSFont.systemFont(ofSize: 22),
                color: NSColor(white: 0.08, alpha: 1),
                onChange: { model.query = $0 }
            )
            .padding(.horizontal, 22)
            .frame(height: LauncherMetrics.queryHeight)
            .background { SpotlightFieldBackground() }
            .padding(.horizontal, searching ? 12 : 0)
            .padding(.top, searching ? 12 : 0)
            .padding(.bottom, searching ? 8 : 0)
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
                resultList(theme)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
            }
        }
        .background {
            if searching {
                RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                    .fill(theme.background)
                    .background {
                        if theme.material != nil {
                            RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                                .fill(theme.material ?? .ultraThin)
                        }
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: searching ? theme.radius : LauncherMetrics.queryHeight / 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: searching ? theme.radius : LauncherMetrics.queryHeight / 2, style: .continuous)
                .stroke(Color.white.opacity(searching ? 0.28 : 0), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.28), radius: 28, y: 16)
        .onChange(of: model.query) { _, _ in model.scheduleSearch() }
    }

    private func resultList(_ theme: LauncherTheme) -> some View {
        let shown = min(max(model.results.count, 1), LauncherMetrics.visibleRows)
        return ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 2) {
                    if model.results.isEmpty {
                        Text("No matches")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.subtitle)
                            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                            .padding(.horizontal, 14)
                    } else {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, item in
                            LauncherRow(item: item, index: index, selected: index == model.selection, theme: theme)
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture { model.commitIndex(index) }
                        }
                    }
                }
            }
            .scrollIndicators(model.results.count > LauncherMetrics.visibleRows ? .visible : .hidden)
            .frame(height: CGFloat(shown) * LauncherMetrics.rowStride - 2)
            .onChange(of: model.selection) { _, newValue in
                proxy.scrollTo(newValue)
            }
            .onChange(of: model.results.map(\.id)) { _, _ in
                let index = model.results.isEmpty ? 0 : min(model.selection, model.results.count - 1)
                proxy.scrollTo(index, anchor: .top)
            }
        }
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
        field.placeholderString = ""
        field.appearance = NSAppearance(named: .aqua)
        let cell = VerticallyCenteredTextFieldCell(textCell: text)
        cell.font = font
        cell.textColor = color
        cell.isEditable = true
        cell.isSelectable = true
        cell.isBordered = false
        cell.drawsBackground = false
        cell.focusRingType = .none
        cell.usesSingleLineMode = true
        field.cell = cell
        field.delegate = context.coordinator
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

enum LauncherMetrics {
    static let visibleRows = 9
    static let rowStride: CGFloat = 70
    static let queryHeight: CGFloat = 58
}

struct SpotlightFieldBackground: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .light)
            .overlay {
                LinearGradient(
                    colors: [Color.white.opacity(0.62), Color(white: 0.72).opacity(0.28)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(Capsule(style: .continuous))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.85), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
    }
}

final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let original = super.drawingRect(forBounds: rect)
        let textHeight = cellSize(forBounds: rect).height
        let y = rect.origin.y + (rect.height - textHeight) / 2
        return NSRect(x: original.origin.x, y: y, width: original.width, height: textHeight)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let inset = drawingRect(forBounds: rect)
        super.select(withFrame: inset, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
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
                    .font(theme.font(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? theme.selectedTitle : theme.title)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? theme.selectedSubtitle : theme.subtitle)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(shortcut)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selected ? theme.selectedSubtitle : theme.subtitle)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 66, maxHeight: 66, alignment: .leading)
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
                .font(.system(size: 22))
                .foregroundStyle(Color(white: 0.08))
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: LauncherMetrics.queryHeight)
                .background { SpotlightFieldBackground() }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
            VStack(spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 12) {
                        Image(systemName: String(row.2.dropFirst("symbol:".count)))
                            .font(.system(size: 26))
                            .frame(width: 40)
                            .foregroundStyle(index == 0 ? theme.selectedTitle : theme.title)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.0).font(theme.font(size: 18, weight: .semibold)).foregroundStyle(index == 0 ? theme.selectedTitle : theme.title)
                            Text(row.1).font(.system(size: 13)).foregroundStyle(index == 0 ? theme.selectedSubtitle : theme.subtitle).lineLimit(1)
                        }
                        Spacer()
                        Text(index == 0 ? "↩" : "⌘\(index + 1)")
                            .foregroundStyle(index == 0 ? theme.selectedSubtitle : theme.subtitle)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 66)
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
