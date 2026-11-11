import AppKit
import JfredCore
import QuartzCore
import QuickLookUI
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
    nonisolated(unsafe) private var keyMonitor: Any?
    nonisolated(unsafe) private var mouseMonitor: Any?
    nonisolated(unsafe) private var globalMonitor: Any?
    nonisolated(unsafe) private var scrollMonitor: Any?
    private var quickLookPath: String?
    private var quickLookController: QuickLookPreviewController?
    private var pinnedTop: CGFloat?
    private var hasPlaced = false
    private var ignoreMove = false
    private var layoutToken = 0
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
        host.sizingOptions = []
        panel.contentView = host
        self.panel = panel
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] note in
            // The observer runs on the main queue. The block itself is not main-actor
            // isolated, so take the window out of the sending check and read its frame there.
            nonisolated(unsafe) let object = note.object
            MainActor.assumeIsolated {
                guard self?.ignoreMove != true else { return }
                if let maxY = (object as? NSWindow)?.frame.maxY {
                    self?.pinnedTop = maxY
                }
            }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.localMouse(event) ?? event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.globalMouse(event)
        }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.localScroll(event) ?? event
        }
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
    }

    func showQuickLook(path: String) {
        quickLookPath = path
        let controller = quickLookController ?? QuickLookPreviewController()
        quickLookController = controller
        controller.path = path
        guard let preview = QLPreviewPanel.shared() else { return }
        preview.dataSource = controller
        preview.delegate = controller
        preview.reloadData()
        if let panel, let screen = panel.screen ?? NSScreen.main {
            var frame = preview.frame
            if frame.width < 480 { frame.size.width = 640 }
            if frame.height < 320 { frame.size.height = 480 }
            frame.origin.x = panel.frame.midX - frame.width / 2
            frame.origin.y = max(screen.visibleFrame.minY + 40, panel.frame.minY - frame.height - 12)
            preview.setFrame(frame, display: false)
        }
        preview.makeKeyAndOrderFront(nil)
    }

    func show() {
        guard let panel else { return }
        if !hasPlaced || !isOnVisibleScreen(panel.frame) {
            hasPlaced = placeInitially()
        }
        layout(animated: false)
        // A nonactivating panel can take keystrokes without pulling other
        // Jfred windows, such as Preferences, in front of Finder.
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func hide() { panel?.orderOut(nil) }

    /// `animated` only eases a panel that is already on screen. The hotkey
    /// path passes false so the window appears at its final height.
    func layout(animated: Bool = true) {
        guard let panel else { return }
        let frame = panelFrame(for: panel)
        let heightDelta = abs(frame.height - panel.frame.height)
        layoutToken += 1
        let token = layoutToken
        ignoreMove = true
        if animated && panel.isVisible && heightDelta > 0.5 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.08
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            } completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.layoutToken == token else { return }
                    self.ignoreMove = false
                    self.pinnedTop = self.panel?.frame.maxY ?? frame.maxY
                }
            }
            pinnedTop = frame.maxY
            return
        }
        if frame != panel.frame {
            panel.setFrame(frame, display: true)
        }
        pinnedTop = panel.frame.maxY
        ignoreMove = false
    }

    private func panelFrame(for panel: NSPanel) -> NSRect {
        let theme = LauncherTheme.by(id: model.preferences.themeID, custom: model.preferences.customThemes)
        let rows = min(listRowCount(), LauncherMetrics.visibleRows)
        let listHeight = LauncherMetrics.listHeight(rows: rows, rowHeight: theme.rowHeight)
        let buffer: CGFloat = model.fileBuffer.isEmpty ? 0 : 34
        let header = theme.paddingV + theme.queryBoxHeight + (rows > 0 ? 6 : theme.paddingV)
        let height = header + buffer + listHeight + (rows > 0 ? theme.paddingV : 0)
        var frame = panel.frame
        let top = pinnedTop ?? frame.maxY
        let preview = ClipboardPreview.isViewerQuery(model.query, keyword: model.preferences.clipboardViewerKeyword)
            ? LauncherMetrics.clipboardPreviewWidth
            : 0
        let width = theme.width + preview
        let delta = width - frame.width
        frame.size = NSSize(width: width, height: height)
        frame.origin.x -= delta / 2
        frame.origin.y = top - height
        if let screen = panel.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            if frame.minX < visible.minX { frame.origin.x = visible.minX }
            if frame.maxX > visible.maxX { frame.origin.x = visible.maxX - frame.width }
            if frame.minY < visible.minY {
                frame.origin.y = max(visible.minY, visible.maxY - frame.height)
            }
        }
        return frame
    }

    private func listRowCount() -> Int {
        if model.actionPanelVisible {
            return max(model.launcherActions.count, 1)
        }
        if model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return 0
        }
        return max(model.results.count, 1)
    }

    func showLarge(_ text: String, size: Double, font: String) {
        let mouse = NSEvent.mouseLocation
        let mouseScreen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
        let target = model.preferences.largeTypeShowOnMouseScreen ? (mouseScreen ?? NSScreen.main) : NSScreen.main
        let panel = NSPanel(
            contentRect: target?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: LargeTypeView(text: text, size: size, fontName: font, fitBackground: model.preferences.largeTypeBackgroundMode == "fit") { [weak self] in
            self?.largePanel?.orderOut(nil)
            self?.largePanel = nil
        })
        panel.contentView = host
        if let screen = target ?? NSScreen.screens.first {
            panel.setFrame(screen.frame, display: true)
        }
        panel.makeKeyAndOrderFront(nil)
        largePanel = panel
    }

    @discardableResult
    private func placeInitially() -> Bool {
        guard let panel else { return false }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return false }
        let visible = screen.visibleFrame
        var frame = panel.frame
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.maxY - 150 - frame.height
        panel.setFrame(frame, display: false)
        pinnedTop = panel.frame.maxY
        return true
    }

    private func isOnVisibleScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            let visible = screen.visibleFrame
            return visible.intersects(frame) && frame.minX >= visible.minX - 1
        }
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

    /// The query field is first responder, so the wheel can miss the result
    /// list. Forward the event to the scroll view under the pointer (or the
    /// clipboard history list) without changing the selection or hiding.
    private func localScroll(_ event: NSEvent) -> NSEvent? {
        guard model.launcherVisible, event.window === panel, let panel, let content = panel.contentView else { return event }
        let point = content.convert(event.locationInWindow, from: nil)
        let hit = content.hitTest(point)
        if let scroll = enclosingScrollView(hit) {
            scroll.scrollWheel(with: event)
            return nil
        }
        let viewer = ClipboardPreview.isViewerQuery(model.query, keyword: model.preferences.clipboardViewerKeyword)
        if viewer, let scroll = resultsScrollView(), pointerIsOverResultList(point, in: content) {
            scroll.scrollWheel(with: event)
            return nil
        }
        return event
    }

    private func enclosingScrollView(_ view: NSView?) -> NSScrollView? {
        var current = view
        while let view = current {
            if let scroll = view as? NSScrollView { return scroll }
            current = view.superview
        }
        return nil
    }

    private func resultsScrollView() -> NSScrollView? {
        guard let content = panel?.contentView else { return nil }
        let views = scrollViews(in: content)
        guard !views.isEmpty else { return nil }
        return views.min { lhs, rhs in
            lhs.convert(lhs.bounds, to: content).minX < rhs.convert(rhs.bounds, to: content).minX
        }
    }

    private func scrollViews(in view: NSView) -> [NSScrollView] {
        var found: [NSScrollView] = []
        if let scroll = view as? NSScrollView { found.append(scroll) }
        for child in view.subviews {
            found.append(contentsOf: scrollViews(in: child))
        }
        return found
    }

    private func pointerIsOverResultList(_ point: NSPoint, in content: NSView) -> Bool {
        let theme = LauncherTheme.by(id: model.preferences.themeID, custom: model.preferences.customThemes)
        let bounds = content.bounds
        let listMaxX = bounds.minX + theme.width
        if point.x < bounds.minX || point.x > listMaxX { return false }
        if content.isFlipped {
            let queryBottom = bounds.minY + theme.paddingV + theme.queryBoxHeight + 6
            return point.y >= queryBottom
        }
        let queryBottom = bounds.maxY - (theme.paddingV + theme.queryBoxHeight + 6)
        return point.y <= queryBottom
    }

    /// Return, Escape, Tab and the arrows confirm, cancel or move an IME
    /// candidate. While the field editor has marked text, those keys belong to
    /// the input method. Swallowing them searches or dismisses the launcher
    /// before the candidate is committed.
    private func defersToInputMethod(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 36, 76, 53, 48, 123, 124, 125, 126:
            break
        default:
            return false
        }
        return editingTextView()?.hasMarkedText() == true
    }

    private func editingTextView() -> NSTextView? {
        guard let responder = panel?.firstResponder else { return nil }
        if let editor = responder as? NSTextView { return editor }
        if let field = responder as? NSTextField { return field.currentEditor() as? NSTextView }
        return nil
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard model.launcherVisible, panel?.isKeyWindow == true else { return event }
        if defersToInputMethod(event) { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if model.actionPanelVisible {
            if flags.contains(.command),
               let chars = event.charactersIgnoringModifiers,
               let number = Int(chars),
               (1...9).contains(number) {
                model.commitAction(at: number - 1)
                return nil
            }
            switch event.keyCode {
            case 125: model.moveAction(1); return nil
            case 126: model.moveAction(-1); return nil
            case 36, 76: model.commitAction(); return nil
            case 53, 123: model.backActions(); return nil
            default: model.closeActions()
            }
        }
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
        case 124:
            if showsActions(flags) { model.showActions() }
            return nil
        case 63 where model.preferences.uaShowFunction:
            model.showActions()
            return nil
        case 59 where model.preferences.uaShowControl:
            model.showActions()
            return nil
        case 62 where model.preferences.uaShowControl:
            model.showActions()
            return nil
        case 54 where model.preferences.uaShowCommand:
            model.showActions()
            return nil
        case 55 where model.preferences.uaShowCommand:
            model.showActions()
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
            if chars == "k" { model.showActions(); return nil }
        }
        return event
    }

    private func showsActions(_ flags: NSEvent.ModifierFlags) -> Bool {
        if model.preferences.uaShowRightArrow { return true }
        if flags.contains(.function), model.preferences.uaShowFunction { return true }
        if flags.contains(.control), model.preferences.uaShowControl { return true }
        if flags.contains(.command), model.preferences.uaShowCommand { return true }
        return false
    }
}

struct LauncherRoot: View {
    var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = LauncherTheme.by(id: model.preferences.themeID, custom: model.preferences.customThemes, colorScheme: colorScheme)
        let searching = !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        VStack(alignment: .leading, spacing: 0) {
            QueryField(
                text: model.query,
                token: model.focusToken,
                font: theme.queryNSFont,
                color: NSColor(theme.query),
                onChange: { model.query = $0 }
            )
            .padding(.horizontal, 10)
            .frame(height: theme.queryBoxHeight)
            .overlay(alignment: .trailing) {
                if let busy = model.searchingSubtitle {
                    SearchActivityIndicator(label: busy)
                        .padding(.trailing, 10)
                }
            }
            .background { LauncherFieldBackground(color: theme.searchBackground, radius: theme.fieldRadius) }
            .padding(.horizontal, theme.paddingH)
            .padding(.top, theme.paddingV)
            .padding(.bottom, searching ? 6 : theme.paddingV)
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
            if model.actionPanelVisible {
                actionList(theme)
                    .padding(.horizontal, theme.paddingH)
                    .padding(.bottom, theme.paddingV)
            } else if !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if showsClipboardPreview {
                    clipboardHistoryBody(theme)
                } else {
                    resultList(theme)
                        .padding(.horizontal, theme.paddingH)
                        .padding(.bottom, theme.paddingV)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .jfredLauncherSurface(theme: theme)
        .onChange(of: model.query) { _, _ in
            model.closeActions()
            model.scheduleSearch()
        }
    }

    private var showsClipboardPreview: Bool {
        ClipboardPreview.isViewerQuery(model.query, keyword: model.preferences.clipboardViewerKeyword)
    }

    private func clipboardHistoryBody(_ theme: LauncherTheme) -> some View {
        let count = model.results.count
        let shown = min(max(count, 1), LauncherMetrics.visibleRows)
        let height = LauncherMetrics.listHeight(rows: shown, rowHeight: theme.rowHeight)
        return HStack(alignment: .top, spacing: 0) {
            resultList(theme)
                .frame(width: theme.width - theme.paddingH * 2)
                .padding(.leading, theme.paddingH)
            Rectangle()
                .fill(theme.border.opacity(0.45))
                .frame(width: 1)
                .padding(.vertical, 2)
            ClipboardPreviewPane(model: model, theme: theme)
                .frame(width: LauncherMetrics.clipboardPreviewWidth - theme.paddingH)
                .padding(.trailing, 4)
        }
        .frame(height: height)
        .padding(.bottom, theme.paddingV)
        .transaction { $0.animation = nil }
    }

    private func actionList(_ theme: LauncherTheme) -> some View {
        let count = model.launcherActions.count
        let shown = min(max(count, 1), LauncherMetrics.visibleRows)
        let height = LauncherMetrics.listHeight(rows: shown, rowHeight: theme.rowHeight)
        return Group {
            if count <= LauncherMetrics.visibleRows {
                actionRows(theme, lazy: false)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        actionRows(theme, lazy: true)
                    }
                    .scrollIndicators(.visible)
                    .onChange(of: model.actionIndex) { _, newValue in
                        guard model.launcherActions.indices.contains(newValue) else { return }
                        proxy.scrollTo(model.launcherActions[newValue].id)
                    }
                }
            }
        }
        .frame(height: height)
        .transaction { $0.animation = nil }
    }

    private func actionRows(_ theme: LauncherTheme, lazy: Bool) -> some View {
        RowStack(lazy: lazy) {
            ForEach(Array(model.launcherActions.enumerated()), id: \.element.id) { index, action in
                LauncherActionRow(action: action, index: index, selected: index == model.actionIndex, theme: theme)
                    .id(action.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.actionIndex = index
                        model.commitAction()
                    }
            }
        }
        .animation(.none, value: model.actionIndex)
    }

    private func resultList(_ theme: LauncherTheme) -> some View {
        let count = model.results.count
        let shown = min(max(count, 1), LauncherMetrics.visibleRows)
        let height = LauncherMetrics.listHeight(rows: shown, rowHeight: theme.rowHeight)
        return Group {
            if count <= LauncherMetrics.visibleRows {
                resultRows(theme, lazy: false)
            } else {
                // Only rows scrolled into view are built, so a long list does
                // not lay out (or draw icons for) rows nobody sees.
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        resultRows(theme, lazy: true)
                    }
                    .scrollIndicators(.visible)
                    .onChange(of: model.selection) { _, newValue in
                        guard model.results.indices.contains(newValue) else { return }
                        proxy.scrollTo(model.results[newValue].id)
                    }
                }
            }
        }
        .frame(height: height)
        .transaction { $0.animation = nil }
    }

    private func resultRows(_ theme: LauncherTheme, lazy: Bool) -> some View {
        RowStack(lazy: lazy) {
            if model.results.isEmpty {
                Text("No matches")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.subtitle)
                    .frame(maxWidth: .infinity, minHeight: theme.rowHeight, maxHeight: theme.rowHeight, alignment: .leading)
                    .padding(.horizontal, 14)
            } else {
                ForEach(Array(model.results.enumerated()), id: \.element.id) { index, item in
                    resultRow(item, index: index, theme: theme)
                }
            }
        }
        .animation(.none, value: model.selection)
        .animation(.none, value: model.results.map(\.id))
    }

    @ViewBuilder
    private func resultRow(_ item: SearchResult, index: Int, theme: LauncherTheme) -> some View {
        let row = LauncherRow(item: item, index: index, selected: index == model.selection, theme: theme)
            .id(item.id)
            .contentShape(Rectangle())
        let clicked = resultClick(row, index: index)
        if item.kind == "app", item.payload.hasPrefix("/") {
            clicked.contextMenu { appFileMenu(item) }
        } else {
            clicked
        }
    }

    @ViewBuilder
    private func resultClick(_ row: some View, index: Int) -> some View {
        if showsClipboardPreview {
            row
                .onTapGesture(count: 2) { model.handleResultClick(index: index, clickCount: 2) }
                .onTapGesture(count: 1) { model.handleResultClick(index: index, clickCount: 1) }
        } else {
            row.onTapGesture { model.commitIndex(index) }
        }
    }

    @ViewBuilder
    private func appFileMenu(_ item: SearchResult) -> some View {
        ForEach(FileActions.items(kind: item.kind, path: item.payload)) { action in
            if action.id == .recentDocuments {
                Menu(action.title) {
                    recentDocumentMenu(item.payload)
                }
            } else {
                Button(action.title) {
                    model.perform(fileAction: action.id, on: item)
                }
            }
        }
    }

    @ViewBuilder
    private func recentDocumentMenu(_ path: String) -> some View {
        let documents = RecentDocuments.urls(forAppAt: path)
        if documents.isEmpty {
            Button("No Recent Documents") {}
                .disabled(true)
        } else {
            ForEach(documents) { document in
                Button(document.name) {
                    model.openFile(document.path)
                }
                .help(document.path)
            }
        }
    }
}

/// A plain stack for lists that fit on screen; a lazy one inside a scroll view.
/// Rows have a fixed height, so the lazy stack sizes its content without
/// building every row, and `ScrollViewReader` can still scroll to any row.
private struct RowStack<Content: View>: View {
    var lazy: Bool
    @ViewBuilder var content: Content

    var body: some View {
        if lazy {
            LazyVStack(spacing: LauncherMetrics.rowGap) { content }
        } else {
            VStack(spacing: LauncherMetrics.rowGap) { content }
        }
    }
}

/// A small spinner at the end of the query field while a file search or
/// Script Filter is still working and older rows are on screen. It fades in
/// after a short wait, so queries that answer at once do not flash it.
private struct SearchActivityIndicator: View {
    var label: String
    @State private var visible = false

    var body: some View {
        ProgressView()
            .controlSize(.small)
            .scaleEffect(0.8)
            .frame(width: 16, height: 16)
            .opacity(visible ? 1 : 0)
            .help(label)
            .accessibilityLabel(label)
            .allowsHitTesting(false)
            .task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.12)) { visible = true }
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
        if let editor = field.currentEditor() as? NSTextView {
            // Reflect programmatic changes (workflow completion, history, URL
            // queries) in the active field editor, but never while an IME is
            // composing text.
            if !editor.hasMarkedText(), editor.string != text {
                editor.string = text
                editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            }
        } else if field.stringValue != text {
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
    static let rowGap: CGFloat = 2
    /// Right-hand preview column shown in the clipboard viewer.
    static let clipboardPreviewWidth: CGFloat = 360

    static func listHeight(rows: Int, rowHeight: CGFloat) -> CGFloat {
        guard rows > 0 else { return 0 }
        return CGFloat(rows) * rowHeight + CGFloat(rows - 1) * rowGap
    }
}

/// Search field: a slightly recessed rounded rectangle that sits
/// inside the panel, rather than a bright capsule floating over it. Because
/// the panel is always drawn, the field has the same backdrop and colour in
/// the empty and expanded states.
struct LauncherFieldBackground: View {
    var color: Color = Color.black.opacity(0.10)
    var radius: CGFloat = 4
    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(color)
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
        HStack(spacing: theme.iconPadding + 4) {
            ResultIcon(icon: item.icon, tint: selected ? theme.selectedTitle : theme.title, size: theme.iconSize)
            VStack(alignment: .leading, spacing: theme.textSpacing) {
                Text(item.title)
                    .font(theme.font(size: theme.resultTextSize, weight: .regular))
                    .foregroundStyle(selected ? theme.selectedTitle : theme.title)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: theme.resultSubtextSize))
                    .foregroundStyle(selected ? theme.selectedSubtitle : theme.subtitle)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if item.badge.isEmpty {
                Text(shortcut)
                    .font(.system(size: theme.shortcutSize, weight: .regular))
                    .foregroundStyle(selected ? theme.selectedSubtitle : theme.subtitle)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    ResultIcon(icon: item.badge, size: 16)
                        .frame(width: 16, height: 16)
                        .help(item.badgeName)
                    Spacer(minLength: 0)
                    Text(shortcut)
                        .font(.system(size: theme.shortcutSize, weight: .regular))
                        .foregroundStyle(selected ? theme.selectedSubtitle : theme.subtitle)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(height: theme.rowHeight - theme.rowPaddingV * 2)
            }
        }
        .padding(.horizontal, theme.paddingH)
        .frame(maxWidth: .infinity, minHeight: theme.rowHeight, maxHeight: theme.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.rowHighlightRadius, style: .continuous)
                .fill(selected ? theme.selected : Color.clear)
        )
    }
}

struct LauncherActionRow: View {
    var action: LauncherAction
    var index: Int
    var selected: Bool
    var theme: LauncherTheme

    private var shortcut: String {
        if selected { return "↩" }
        guard index < 9 else { return "" }
        return "⌘\(index + 1)"
    }

    var body: some View {
        HStack(spacing: theme.iconPadding + 4) {
            Image(systemName: action.symbol)
                .font(.system(size: theme.iconSize * 0.45))
                .foregroundStyle(selected ? theme.selectedTitle : theme.title)
                .frame(width: theme.iconSize)
            VStack(alignment: .leading, spacing: theme.textSpacing) {
                Text(action.title)
                    .font(theme.font(size: theme.resultTextSize, weight: .regular))
                    .foregroundStyle(selected ? theme.selectedTitle : theme.title)
                    .lineLimit(1)
                Text(action.subtitle)
                    .font(.system(size: theme.resultSubtextSize))
                    .foregroundStyle(selected ? theme.selectedSubtitle : theme.subtitle)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(shortcut)
                .font(.system(size: theme.shortcutSize))
                .foregroundStyle(selected ? theme.selectedSubtitle : theme.subtitle)
        }
        .padding(.horizontal, theme.paddingH)
        .frame(maxWidth: .infinity, minHeight: theme.rowHeight, maxHeight: theme.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.rowHighlightRadius, style: .continuous)
                .fill(selected ? theme.selected : Color.clear)
        )
    }
}

struct LargeTypeView: View {
    var text: String
    var size: Double
    var fontName: String
    var fitBackground: Bool
    var dismiss: () -> Void

    var body: some View {
        ZStack {
            if !fitBackground {
                Color.black.opacity(0.28).ignoresSafeArea()
            }
            Text(text)
                .font(fontName == "System" ? .system(size: size, weight: .semibold) : .custom(fontName, size: size))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.2)
                .padding(.horizontal, fitBackground ? 64 : 48)
                .padding(.vertical, fitBackground ? 44 : 48)
                .background {
                    if fitBackground {
                        largeTypeBackdrop
                    }
                }
                .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
        }
        .onTapGesture { dismiss() }
        .onExitCommand { dismiss() }
    }

    @ViewBuilder private var largeTypeBackdrop: some View {
        let shape = RoundedRectangle(cornerRadius: JfredMetrics.windowRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            shape.fill(Color.black.opacity(0.28)).glassEffect(.regular.tint(Color.black.opacity(0.45)), in: shape)
        } else {
            shape.fill(Color.black.opacity(0.60))
        }
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
                .font(theme.queryFont)
                .foregroundStyle(theme.query)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: theme.queryBoxHeight)
                .background { LauncherFieldBackground(color: theme.searchBackground, radius: theme.fieldRadius) }
                .padding(.horizontal, theme.paddingH)
                .padding(.top, theme.paddingV)
                .padding(.bottom, 6)
            VStack(spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: theme.iconPadding + 4) {
                        Image(systemName: String(row.2.dropFirst("symbol:".count)))
                            .font(.system(size: theme.iconSize * 0.62))
                            .frame(width: theme.iconSize)
                            .foregroundStyle(index == 0 ? theme.selectedTitle : theme.title)
                        VStack(alignment: .leading, spacing: theme.textSpacing) {
                            Text(row.0).font(theme.font(size: theme.resultTextSize, weight: .regular)).foregroundStyle(index == 0 ? theme.selectedTitle : theme.title)
                            Text(row.1).font(.system(size: theme.resultSubtextSize)).foregroundStyle(index == 0 ? theme.selectedSubtitle : theme.subtitle).lineLimit(1)
                        }
                        Spacer()
                        Text(index == 0 ? "↩" : "⌘\(index + 1)")
                            .font(.system(size: theme.shortcutSize))
                            .foregroundStyle(index == 0 ? theme.selectedSubtitle : theme.subtitle)
                    }
                    .padding(.horizontal, theme.paddingH)
                    .frame(height: theme.rowHeight)
                    .background(RoundedRectangle(cornerRadius: theme.rowHighlightRadius, style: .continuous).fill(index == 0 ? theme.selected : Color.clear))
                }
            }
            .padding(.horizontal, theme.paddingH)
            .padding(.bottom, theme.paddingV)
        }
        .frame(width: theme.width)
        .jfredLauncherSurface(theme: theme)
    }
}


final class QuickLookPreviewController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var path: String?

    func numberOfPreviewItems(in panel: QLPreviewPanel) -> Int {
        path == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel, previewItemAt index: Int) -> (any QLPreviewItem)? {
        guard let path else { return nil }
        return URL(fileURLWithPath: path) as QLPreviewItem
    }
}
