import AppKit
import SwiftUI
import JfredCore
import UniformTypeIdentifiers

private enum WorkflowCanvas {
    static let nodeWidth: CGFloat = 120
    static let nodeHeight: CGFloat = 100
}

private enum WorkflowChrome {
    static let canvas = Color(hex: 0xF3F3F5)
    static let sidebar = Color(hex: 0xECECF0)
    static let rail = Color(hex: 0xE6E6EA)
    static let header = Color(hex: 0xEFEFF2)
    static let well = Color(hex: 0xE0E0E5)
    static let hairline = Color.black.opacity(0.10)
    static let selectedRow = Color.accentColor.opacity(0.16)
    static let primary = Color(hex: 0x1D1D1F)
    static let secondary = Color(hex: 0x6E6E73)
}

/// Read-only preview of an external script. The text stays gray and cannot be edited in the sheet.
private struct ScriptFilePreview: NSViewRepresentable {
    var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = Self.fill
        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        configure(textView)
        textView.string = text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        scroll.backgroundColor = Self.fill
        guard let textView = scroll.documentView as? NSTextView else { return }
        configure(textView)
        if textView.string != text {
            textView.string = text
        }
    }

    private func configure(_ textView: NSTextView) {
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = .secondaryLabelColor
        textView.backgroundColor = Self.fill
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
    }

    private static let fill = NSColor(white: 0.94, alpha: 1)
}

private func artworkImage(from ref: WorkflowIconRef) -> NSImage? {
    switch ref {
    case .image(let path):
        return NSImage(contentsOfFile: path)
    default:
        return nil
    }
}

private func workflowIconImage(_ workflow: Workflow) -> NSImage? {
    artworkImage(from: workflow.resolvedIcon())
}

private func objectIconImage(_ object: WorkflowObject, workflow: Workflow?) -> NSImage? {
    guard let workflow else { return nil }
    let configured = object.config[string: "icon"]
    if !configured.isEmpty {
        if let image = artworkImage(from: WorkflowIcon.resolve(
            path: configured,
            workflowRoot: workflow.rootPath,
            workflowSymbol: workflow.symbol,
            objectUID: object.alfredUID
        )) {
            return image
        }
    }
    return artworkImage(from: workflow.resolvedIcon(objectUID: object.alfredUID))
}

struct WorkflowsPane: View {
    var model: AppModel

    @State private var dropTargeted = false

    private var visible: [Workflow] {
        let query = model.workflowFilter.trimmingCharacters(in: .whitespaces)
        return model.workflows.filter { workflow in
            if model.hideDisabledWorkflows && !workflow.enabled { return false }
            if query.isEmpty { return true }
            return workflow.name.localizedCaseInsensitiveContains(query)
                || workflow.keyword.localizedCaseInsensitiveContains(query)
                || workflow.author.localizedCaseInsensitiveContains(query)
                || workflow.bundleID.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            if let id = model.selectedWorkflow, model.workflows.contains(where: { $0.id == id }) {
                WorkflowEditor(model: model, workflowID: id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
            }
        }
        .sheet(isPresented: model.bind(\.showTemplates)) { templateSheet }
        .background(WorkflowChrome.canvas)
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: handleWorkflowDrop)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .padding(3)
                    .allowsHitTesting(false)
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0x8A8A8A))
                ZStack(alignment: .leading) {
                    if model.workflowFilter.isEmpty {
                        Text("Filter").font(.system(size: 12)).foregroundStyle(Color(hex: 0x8A8A8A))
                    }
                    TextField("", text: model.bind(\.workflowFilter))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0x333333))
                }
                Menu {
                    workflowGearMenu
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: 0x8A8A8A))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("Workflow options")
            }
            .padding(.horizontal, 7)
            .frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color(hex: 0xF6F6F6)))
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 6)

            if !model.workflowImportStatus.isEmpty {
                Text(model.workflowImportStatus)
                    .font(.system(size: 10.5))
                    .foregroundStyle(model.workflowImportStatus.hasPrefix("Could not") ? Color.orange : WorkflowChrome.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visible) { workflow in
                        workflowRow(workflow)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Button("Browse Gallery") {
                    if let url = URL(string: "https://alfred.app/") { NSWorkspace.shared.open(url) }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .frame(width: 104, height: 28)
                .background(WorkflowChrome.well)
                Button("Help") { model.section = .help }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                Spacer()
                Button {
                    chooseWorkflowToImport()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Import a workflow")
                Menu {
                    Button("New Workflow") { model.beginWorkflowEdit(blank()) }
                    Button("New from Template…") { model.showTemplates = true }
                    Divider()
                    Button("Import Workflow…") { chooseWorkflowToImport() }
                } label: {
                    Text("+")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("Add or import a workflow")
                Button("−") {
                    guard let id = model.selectedWorkflow else { return }
                    model.removeWorkflow(id)
                }
                .buttonStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 24)
            }
            .foregroundStyle(WorkflowChrome.primary)
            .padding(.horizontal, 6)
            .frame(height: 28)
            .background(WorkflowChrome.rail)
            .overlay(alignment: .top) { Rectangle().fill(WorkflowChrome.hairline).frame(height: 1) }
        }
        .frame(width: 253)
        .background(WorkflowChrome.sidebar)
    }

    private func workflowRow(_ workflow: Workflow) -> some View {
        Button {
            if model.editingWorkflowID != nil { model.saveWorkflowEdit() }
            model.beginWorkflowEdit(workflow)
            model.selectedWorkflowObject = workflow.searchInputs.first?.id
        } label: {
            HStack(spacing: 8) {
                if let icon = workflowIconImage(workflow) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                } else {
                    Image(systemName: workflow.symbol)
                        .font(.system(size: 13))
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 7).fill(tintColor(workflow.tint)))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(workflow.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    Text(workflow.isMissingBundle ? "Missing on disk" : (workflow.author.isEmpty ? "by You" : "by \(workflow.author)"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(workflow.isMissingBundle ? Color.orange.opacity(0.95) : WorkflowChrome.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(height: 42)
            .foregroundStyle(WorkflowChrome.primary)
            .opacity(workflow.enabled ? 1 : 0.55)
            .saturation(workflow.enabled ? 1 : 0.15)
            .background(model.selectedWorkflow == workflow.id ? WorkflowChrome.selectedRow : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { workflowMenu(workflow) }
    }

    @ViewBuilder
    private func workflowMenu(_ workflow: Workflow) -> some View {
        Toggle("Enabled", isOn: model.bindWorkflow(workflow.id, \.enabled, default: false))
        Divider()
        Button("Configure…") { model.beginWorkflowEdit(workflow) }
        Button("Show in Finder") {
            guard let directory = model.workflowDirectory(workflow) else { return }
            NSWorkspace.shared.activateFileViewerSelecting([directory])
        }
        .disabled(model.workflowDirectory(workflow) == nil)
        Button("Open in Terminal") {
            guard let directory = model.workflowDirectory(workflow) else { return }
            if let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                NSWorkspace.shared.open([directory], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
            }
        }
        .disabled(model.workflowDirectory(workflow) == nil)
        Divider()
        Button("Duplicate") { model.duplicateWorkflow(workflow.id) }
        Button("Export JSON…") { export(workflow, metadataOnly: false) }
        Button("Export Metadata…") { export(workflow, metadataOnly: true) }
        Button("Reload Workflows") { model.reloadWorkflowsFromAlfred() }
        Divider()
        Button("Import Workflow…") { chooseWorkflowToImport() }
        Button("Import from Alfred Library…") { model.importAlfredLibrary() }
        Button("Delete", role: .destructive) {
            model.removeWorkflow(workflow.id)
        }
    }

    @ViewBuilder
    private var workflowGearMenu: some View {
        Button("Import Workflow…") { chooseWorkflowToImport() }
        Button("Import from Alfred Library…") { model.importAlfredLibrary() }
        Divider()
        Button("Reload from Disk") { model.reloadWorkflowsFromAlfred() }
        Button("Reveal Workflows Folder") { model.revealImportedWorkflowsFolder() }
        Divider()
        Button("Export Selected…") {
            guard let id = model.selectedWorkflow, let workflow = model.workflows.first(where: { $0.id == id }) else { return }
            export(workflow, metadataOnly: false)
        }
        .disabled(model.selectedWorkflow == nil)
        Toggle("Hide Disabled Workflows", isOn: model.bind(\.hideDisabledWorkflows))
    }

    private func chooseWorkflowToImport() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsOtherFileTypes = true
        panel.treatsFilePackagesAsDirectories = false
        panel.title = "Import Alfred Workflow"
        panel.message = "Choose a .alfredworkflow file."
        panel.prompt = "Import"
        panel.allowedContentTypes = WorkflowImportPanel.allowedTypes
        presentFilePanel(panel) { url in
            if !WorkflowPackage.isImportableFile(url) && url.pathExtension.lowercased() != "zip" {
                let message = "Could not import \(url.lastPathComponent). It is not an Alfred workflow."
                model.workflowImportStatus = message
                model.presentWorkflowImportAlert(title: "Workflow import failed", message: message)
                return
            }
            model.importWorkflow(at: url)
        }
    }

    private func presentFilePanel(_ panel: NSSavePanel, onOK: @escaping (URL) -> Void) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            panel.level = .modalPanel
            let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "preferences" })
            window?.makeKeyAndOrderFront(nil)
            let handle: (NSApplication.ModalResponse) -> Void = { response in
                guard response == .OK, let url = panel.url else { return }
                onOK(url)
            }
            if let window, window.isVisible {
                panel.beginSheetModal(for: window, completionHandler: handle)
            } else {
                handle(panel.runModal())
            }
        }
    }

    private func handleWorkflowDrop(_ providers: [NSItemProvider]) -> Bool {
        let importable = providers.filter { provider in
            provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !importable.isEmpty else { return false }
        for provider in importable {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    if WorkflowPackage.isImportableFile(url) {
                        model.importWorkflow(at: url)
                    } else {
                        let message = "Could not import \(url.lastPathComponent). It is not an Alfred workflow."
                        model.workflowImportStatus = message
                        model.presentWorkflowImportAlert(title: "Workflow import failed", message: message)
                    }
                }
            }
        }
        return true
    }

    private func export(_ workflow: Workflow, metadataOnly: Bool) {
        let panel = NSSavePanel()
        let base = workflow.name.replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = base + (metadataOnly ? " Metadata.json" : ".jfred-workflow.json")
        panel.allowedContentTypes = [.json]
        presentFilePanel(panel) { url in
            writeExportedWorkflow(workflow, metadataOnly: metadataOnly, to: url)
        }
    }

    private func writeExportedWorkflow(_ workflow: Workflow, metadataOnly: Bool, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data?
        if metadataOnly {
            let metadata: [String: Any] = [
                "name": workflow.name,
                "bundleid": workflow.bundleID,
                "keyword": workflow.keyword,
                "author": workflow.author,
                "version": workflow.version,
                "description": workflow.details,
                "website": workflow.website,
                "objects": workflow.objects.count,
                "connections": workflow.connections.count,
            ]
            data = try? JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        } else {
            data = try? encoder.encode(workflow)
        }
        guard let data else { return }
        try? data.write(to: url, options: .atomic)
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 12) {
                card("sparkles", "Browse Gallery", "Browse community workflows, then import a workflow package.") {
                    if let url = URL(string: "https://alfred.app/") { NSWorkspace.shared.open(url) }
                }
                card("book", "Getting Started Guide", "Learn how objects, connections and variables fit together.") { model.section = .help }
                card("point.3.connected.trianglepath.dotted", "Create a Workflow", "Start with a Keyword and build a graph of actions.") { model.beginWorkflowEdit(blank()) }
                card("square.on.square", "Create from a Template", "Start with a Script Filter, a web search or a shell action.") { model.showTemplates = true }
                card("square.and.arrow.down", "Import a Workflow", "Choose a workflow package, or drag one onto this pane.") { chooseWorkflowToImport() }
            }
            .frame(maxWidth: 650)
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func card(_ symbol: String, _ title: String, _ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .light))
                    .frame(width: 70)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(WorkflowChrome.primary)
                    Text(text).font(.system(size: 12)).foregroundStyle(WorkflowChrome.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 90)
            .background(RoundedRectangle(cornerRadius: JfredMetrics.cardRadius, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: JfredMetrics.cardRadius, style: .continuous).stroke(WorkflowChrome.hairline))
        }
        .buttonStyle(.plain)
    }

    private func blank() -> Workflow {
        Workflow(name: "Untitled Workflow", keyword: "do", author: "You", symbol: "bolt.fill", tint: "561D7E", actions: [
            WorkflowAction(kind: .copy, value: "{query}")
        ])
    }

    private var templateSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Templates").font(.title3)
            Text("Each template is a real object graph you can edit and extend.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            template("Script Filter", "A script returns JSON results; Enter runs the connected action.", .scriptFilter)
            template("Web Search", "Keyword opens a URL with the typed query.", .openURL)
            template("Shell Script", "Keyword runs a shell command with the query.", .runScript)
            template("List Filter", "A static list filtered by Alfred-style matching.", .listFilter)
            Button("Close") { model.showTemplates = false }
        }
        .padding(20)
        .frame(width: 500)
    }

    private func template(_ name: String, _ detail: String, _ kind: WorkflowObjectKind) -> some View {
        Button {
            let workflow = makeTemplate(name: name, kind: kind)
            model.showTemplates = false
            model.beginWorkflowEdit(workflow)
            model.selectedWorkflowObject = workflow.searchInputs.first?.id
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func makeTemplate(name: String, kind: WorkflowObjectKind) -> Workflow {
        let keywordObject: WorkflowObject
        let action: WorkflowObject
        switch kind {
        case .scriptFilter:
            keywordObject = WorkflowObject(kind: .scriptFilter, config: [
                "keyword": .string("demo"),
                "title": .string("Demo..."),
                "subtext": .string("Script Filter"),
                "script": .string("""
                cat <<'JSON'
                {"items":[
                  {"title":"First result","subtitle":"Press Enter","arg":"first"},
                  {"title":"Second result","subtitle":"Press Enter","arg":"second"}
                ]}
                JSON
                """),
                "type": .integer(0),
                "scriptargtype": .integer(1),
                "withspace": .boolean(true),
            ])
            action = WorkflowObject(kind: .clipboard, config: ["clipboardtext": .string("{query}")])
        case .openURL:
            keywordObject = WorkflowObject(kind: .keyword, config: ["keyword": .string("web"), "withspace": .boolean(true)])
            action = WorkflowObject(kind: .openURL, config: ["url": .string("https://www.google.com/search?q={query}")])
        case .listFilter:
            keywordObject = WorkflowObject(kind: .listFilter, config: [
                "keyword": .string("pick"),
                "withspace": .boolean(true),
                "items": .string("""
                [{"title":"Red","subtitle":"A colour","arg":"red"},{"title":"Green","subtitle":"A colour","arg":"green"},{"title":"Blue","subtitle":"A colour","arg":"blue"}]
                """),
            ])
            action = WorkflowObject(kind: .clipboard, config: ["clipboardtext": .string("{query}")])
        default:
            keywordObject = WorkflowObject(kind: .keyword, config: ["keyword": .string("run"), "withspace": .boolean(true)])
            action = WorkflowObject(kind: .runScript, config: [
                "script": .string("echo \"query: {query}\""),
                "type": .integer(0),
                "scriptargtype": .integer(0),
            ])
        }
        let workflow = Workflow(
            name: name,
            author: "You",
            symbol: kind.symbol,
            tint: "561D7E",
            enabled: true,
            builtin: nil,
            objects: [keywordObject, action],
            connections: [WorkflowConnection(source: keywordObject.id, destination: action.id)]
        )
        return workflow
    }

    private func tintColor(_ tint: String) -> Color {
        Color(hex: UInt32(tint, radix: 16) ?? 0x561D7E)
    }
}

struct WorkflowEditor: View {
    var model: AppModel
    var workflowID: UUID

    private var workflow: Workflow? {
        model.workflows.first { $0.id == workflowID }
    }

    private var selectedObject: WorkflowObject? {
        guard let id = model.selectedWorkflowObject else { return nil }
        return workflow?.object(id: id)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                canvas
                debuggerPane
            }
            if model.workflowPaletteVisible { objectPalette }
        }
        .frame(minWidth: 760, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
        .background(WorkflowChrome.canvas)
                .onAppear {
            if model.selectedWorkflowObject == nil {
                model.selectedWorkflowObject = workflow?.searchInputs.first?.id
            }
        }
        .sheet(isPresented: model.bind(\.workflowConfigPresented)) { configSheet }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if let workflow, let icon = workflowIconImage(workflow) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: workflow?.symbol ?? "bolt.fill")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 8).fill(tintColor))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text((workflow?.name ?? "Workflow") + (workflow?.enabled == false ? " - disabled" : ""))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WorkflowChrome.primary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Button("Configure Workflow...") {
                        model.openWorkflowConfig(showsWorkflow: true)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(WorkflowChrome.primary)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .contentShape(Rectangle())
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.06)))
                    Text(workflow?.details.isEmpty == false ? workflow!.details : "Workflow \(workflow?.version ?? "")")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 13) {
                headerButton("keyboard") { model.openWorkflowMetadata() }
                    .help("Workflow hotkey and details")
                headerButton("square.and.arrow.up") { exportCurrentWorkflow() }
                    .help("Export")
                headerButton("ladybug") { model.debuggerVisible.toggle() }
                    .help("Debugger")
                headerButton("list.bullet.rectangle") { model.workflowPaletteVisible.toggle() }
                    .help("Objects palette")
                Menu {
                    Button("Workflow Details...") { model.openWorkflowMetadata() }
                    Button("Duplicate Workflow") { model.duplicateWorkflow(workflowID) }
                    Button("Reload Workflows") { model.reloadWorkflowsFromAlfred() }
                    Divider()
                    Button("Delete Workflow", role: .destructive) {
                        model.removeWorkflow(workflowID)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(WorkflowChrome.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 18)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 90)
        .background(WorkflowChrome.header)
        .overlay(alignment: .bottom) { Rectangle().fill(WorkflowChrome.hairline).frame(height: 1) }
    }

    private func headerButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(WorkflowChrome.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var objectPalette: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12))
                    .foregroundStyle(WorkflowChrome.secondary)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                TextField("", text: model.bind(\.workflowPaletteFilter), prompt: Text("Search Objects").foregroundStyle(WorkflowChrome.secondary))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(WorkflowChrome.primary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WorkflowChrome.secondary)
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WorkflowChrome.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(WorkflowChrome.rail)
            .overlay(alignment: .bottom) { Rectangle().fill(WorkflowChrome.hairline).frame(height: 1) }

            Color.clear.frame(height: 52)

            ScrollView {
                VStack(spacing: 0) {
                    paletteHeaderRow("Getting Started", symbol: "rectangle.grid.2x2") { model.section = .help }
                    paletteHeaderRow("Prefabs", symbol: "square.grid.2x2") { model.showTemplates = true }
                    ForEach(Array(paletteSections.enumerated()), id: \.offset) { _, section in
                        paletteSection(section.0, kinds: section.1)
                    }
                }
            }
        }
        .frame(width: 243)
        .background(WorkflowChrome.sidebar)
    }

    private var paletteSections: [(String, [WorkflowObjectKind])] {
        [
            ("Favourites", [.keyword, .scriptFilter, .runScript, .openURL, .clipboard]),
            ("Triggers", [.hotkey, .universalAction, .externalTriggerInput]),
            ("Inputs", [.keyword, .scriptFilter, .listFilter]),
            ("Actions", [.runScript, .appleScript, .openURL, .openFile, .revealFile, .terminal]),
            ("Automations", [.automationTask]),
            ("User Interface", [.textView, .userInterface]),
            ("Utilities", [.argument, .conditional, .filter, .junction, .delay, .debug, .writeFile]),
            ("Outputs", [.clipboard, .largeType, .notification, .playSound, .speak, .externalTrigger]),
        ]
    }

    private func paletteHeaderRow(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 10)
                Text(title).font(.system(size: 12, weight: .semibold))
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 9))
                    .foregroundStyle(WorkflowChrome.secondary)
            }
            .foregroundStyle(WorkflowChrome.primary)
            .padding(.horizontal, 10)
            .frame(height: 27)
            .background(WorkflowChrome.rail)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func paletteSection(_ title: String, kinds: [WorkflowObjectKind]) -> some View {
        let query = model.workflowPaletteFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = query.isEmpty ? kinds : kinds.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.symbol.localizedCaseInsensitiveContains(query)
        }
        if query.isEmpty || !visible.isEmpty {
            Button {
                model.togglePaletteSection(title)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: model.workflowPaletteExpanded.contains(title) || !query.isEmpty ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 10)
                    Text(title).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 9))
                        .foregroundStyle(WorkflowChrome.secondary)
                }
                .foregroundStyle(WorkflowChrome.primary)
                .padding(.horizontal, 10)
                .frame(height: 27)
                .background(title == "Favourites"
                    ? AnyShapeStyle(LinearGradient(colors: [Color.accentColor.opacity(0.16), Color.accentColor.opacity(0.07)], startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(WorkflowChrome.rail))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if model.workflowPaletteExpanded.contains(title) || !query.isEmpty {
                ForEach(visible, id: \.self) { kind in
                    paletteItem(kind)
                }
            }
        }
    }

    private func paletteItem(_ kind: WorkflowObjectKind) -> some View {
        Button {
            model.addWorkflowObject(kind)
            model.workflowEdited()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0x333333))
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0xE9E9E9)))
                Text(kind.title).font(.system(size: 11, weight: .medium)).foregroundStyle(WorkflowChrome.primary).lineLimit(1)
                Spacer(minLength: 2)
                Image(systemName: paletteSections[0].1.contains(kind) ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 9)
            .frame(height: 27)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var canvas: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                WorkflowChrome.canvas
                    .onTapGesture { model.selectedWorkflowObject = nil }
                ForEach(workflow?.connections ?? []) { connection in
                    connectionPath(connection)
                        .stroke(connectionColor(connection), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        .frame(width: canvasSize.width, height: canvasSize.height)
                }
                ForEach(workflow?.connections ?? []) { connection in
                    connectionDot(connection)
                    connectionLabel(connection)
                }
                ForEach(workflow?.objects ?? []) { object in
                    nodeView(object)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkflowChrome.canvas)
    }

    private var canvasSize: CGSize {
        let maxX = workflow?.objects.map(\.position.x).max() ?? 0
        let maxY = workflow?.objects.map(\.position.y).max() ?? 0
        return CGSize(width: max(920, maxX + WorkflowCanvas.nodeWidth + 120), height: max(560, maxY + WorkflowCanvas.nodeHeight + 100))
    }

    private func nodeSize(_ object: WorkflowObject) -> CGSize {
        object.kind == .argument
            ? CGSize(width: 40, height: 40)
            : CGSize(width: WorkflowCanvas.nodeWidth, height: WorkflowCanvas.nodeHeight)
    }

    @ViewBuilder
    private func nodeView(_ object: WorkflowObject) -> some View {
        let selected = model.selectedWorkflowObject == object.id
        let size = nodeSize(object)
        if object.kind == .argument {
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: 0x333333))
                .frame(width: size.width, height: size.height)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xE5E5E5)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? Color(hex: 0x8AB4F8) : Color.black.opacity(0.6), lineWidth: selected ? 2 : 1))
                .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                .position(x: object.position.x + size.width / 2, y: object.position.y + size.height / 2)
                .onTapGesture(count: 2) {
                    model.selectedWorkflowObject = object.id
                    model.openWorkflowConfig(showsWorkflow: false)
                }
                .onTapGesture { model.selectedWorkflowObject = object.id }
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            if model.workflowDragObjectID != object.id {
                                model.workflowDragObjectID = object.id
                                model.workflowDragStart = object.position
                            }
                            guard let start = model.workflowDragStart else { return }
                            model.moveWorkflowObject(object.id, to: WorkflowPoint(
                                x: max(0, start.x + value.translation.width),
                                y: max(0, start.y + value.translation.height)
                            ))
                        }
                        .onEnded { _ in
                            model.workflowDragObjectID = nil
                            model.workflowDragStart = nil
                            model.workflowEdited()
                        }
                )
        } else {
            let breakpoint = workflow?.objects.firstIndex(where: { $0.id == object.id }).map { model.debugBreakpoints.contains($0) } ?? false
            let note = object.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let caption = object.triggerCaption
            VStack(spacing: 0) {
                VStack(spacing: caption.isEmpty ? 7 : 4) {
                    if !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(textColor(for: object.kind))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 6)
                            .padding(.top, 5)
                    }
                    if let icon = objectIconImage(object, workflow: workflow) {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: caption.isEmpty ? 44 : 36, height: caption.isEmpty ? 44 : 36)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    } else {
                        Image(systemName: object.kind.symbol)
                            .font(.system(size: caption.isEmpty ? 36 : 28, weight: .regular))
                            .foregroundStyle(textColor(for: object.kind))
                    }
                    Text(object.kind.title)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(textColor(for: object.kind))
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .padding(.bottom, caption.isEmpty ? 0 : 4)
                }
                .frame(width: size.width, height: size.height)
                .background(cardColor(for: object.kind))
                if !note.isEmpty {
                    Text(note)
                        .font(.system(size: 8.5))
                        .foregroundStyle(WorkflowChrome.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 6)
                        .frame(width: size.width)
                        .background(Color(hex: 0x353535))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color(hex: 0x8AB4F8) : Color.black.opacity(0.6), lineWidth: selected ? 2 : 1))
            .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
            .overlay(alignment: .topLeading) {
                if breakpoint {
                    Circle().fill(Color.red).frame(width: 7, height: 7).padding(5)
                }
            }
            .position(x: object.position.x + size.width / 2, y: object.position.y + size.height / 2)
            .onTapGesture(count: 2) {
                model.selectedWorkflowObject = object.id
                model.openWorkflowConfig(showsWorkflow: false)
            }
            .onTapGesture { model.selectedWorkflowObject = object.id }
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        if model.workflowDragObjectID != object.id {
                            model.workflowDragObjectID = object.id
                            model.workflowDragStart = object.position
                        }
                        guard let start = model.workflowDragStart else { return }
                        model.moveWorkflowObject(object.id, to: WorkflowPoint(
                            x: max(0, start.x + value.translation.width),
                            y: max(0, start.y + value.translation.height)
                        ))
                    }
                    .onEnded { _ in
                        model.workflowDragObjectID = nil
                        model.workflowDragStart = nil
                        model.workflowEdited()
                    }
            )
        }
    }

    private func cardColor(for kind: WorkflowObjectKind) -> Color {
        switch kind {
        case .hotkey: return Color(hex: 0xF6E6C8)
        case .universalAction: return Color(hex: 0xE7EEF4)
        case .openURL: return Color(hex: 0xB9E7B0)
        case .notification: return Color(hex: 0xF5CDA8)
        case .automationTask: return Color(hex: 0x4B4B4B)
        case .conditional, .filter: return Color(hex: 0xF0D8E8)
        case .clipboard, .largeType: return Color(hex: 0xE8DDF5)
        case .argument, .junction: return Color(hex: 0xE8E8E8)
        default: return Color(hex: 0xE5E5E5)
        }
    }

    private func textColor(for kind: WorkflowObjectKind) -> Color {
        kind == .automationTask ? .white : Color(hex: 0x333333)
    }

    private func connectionPath(_ connection: WorkflowConnection) -> Path {
        guard let source = workflow?.object(id: connection.source),
              let destination = workflow?.object(id: connection.destination) else { return Path() }
        let sourceSize = nodeSize(source)
        let destinationSize = nodeSize(destination)
        let start = CGPoint(x: source.position.x + sourceSize.width, y: source.position.y + sourceSize.height / 2)
        let end = CGPoint(x: destination.position.x, y: destination.position.y + destinationSize.height / 2)
        let bend = max(40, abs(end.x - start.x) * 0.45)
        return Path { path in
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x + bend, y: start.y),
                control2: CGPoint(x: end.x - bend, y: end.y)
            )
        }
    }

    private func connectionLabel(_ connection: WorkflowConnection) -> some View {
        guard let source = workflow?.object(id: connection.source),
              let destination = workflow?.object(id: connection.destination) else { return AnyView(EmptyView()) }
        let sourceSize = nodeSize(source)
        let destinationSize = nodeSize(destination)
        let start = CGPoint(x: source.position.x + sourceSize.width, y: source.position.y + sourceSize.height / 2)
        let end = CGPoint(x: destination.position.x, y: destination.position.y + destinationSize.height / 2)
        let label = connection.subtext.isEmpty ? modifierLabel(connection.modifiers) : connection.subtext
        return AnyView(
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 3)
                .background(Capsule().fill(WorkflowChrome.canvas))
                .position(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 - 6)
        )
    }

    private func connectionColor(_ connection: WorkflowConnection) -> Color {
        if connection.modifiers != 0 { return Color(hex: 0xE0A458) }
        if connection.sourceOutputUID != nil { return Color(hex: 0x9B6BC4) }
        return Color(hex: 0x8B8B8B)
    }

    private func connectionDot(_ connection: WorkflowConnection) -> some View {
        guard let source = workflow?.object(id: connection.source),
              let destination = workflow?.object(id: connection.destination) else { return AnyView(EmptyView()) }
        let sourceSize = nodeSize(source)
        let destinationSize = nodeSize(destination)
        let start = CGPoint(x: source.position.x + sourceSize.width, y: source.position.y + sourceSize.height / 2)
        let end = CGPoint(x: destination.position.x, y: destination.position.y + destinationSize.height / 2)
        return AnyView(
            Circle()
                .fill(Color(hex: 0x2B2B2B))
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(Color(hex: 0x8B8B8B), lineWidth: 1.5))
                .position(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        )
    }

    private func modifierLabel(_ modifiers: Int) -> String {
        if modifiers == 0 { return "" }
        var parts: [String] = []
        if modifiers & Int(Hotkey.command) != 0 { parts.append("⌘") }
        if modifiers & Int(Hotkey.option) != 0 { parts.append("⌥") }
        if modifiers & Int(Hotkey.control) != 0 { parts.append("⌃") }
        if modifiers & Int(Hotkey.shift) != 0 { parts.append("⇧") }
        return parts.joined()
    }

    private var showsNoConfiguration: Bool {
        model.workflowConfigShowsWorkflow
            && !model.workflowConfigEditsMetadata
            && workflow?.builtin != nil
            && (workflow?.userConfiguration.isEmpty ?? true)
    }

    @ViewBuilder
    private var configSheet: some View {
        if showsNoConfiguration {
            noConfigurationSheet
        } else if model.workflowConfigShowsWorkflow {
            metadataSheet
        } else if let object = selectedObject {
            objectSheet(object)
        } else {
            metadataSheet
        }
    }

    private var noConfigurationSheet: some View {
        VStack(spacing: 14) {
            if let workflow, let icon = workflowIconImage(workflow) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 34))
                    .frame(width: 64, height: 64)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xE5E5E5)))
            }
            Text("No Workflow Configuration")
                .font(.system(size: 15, weight: .semibold))
            Text("There is no User Configuration or\nReadme prepared for this workflow.")
                .font(.system(size: 11.5))
                .multilineTextAlignment(.center)
            Text("Workflows can be set up to have easy configuration for users of the workflow, including a custom configuration UI.")
                .font(.system(size: 11.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Use the [x] button in the top right of the editor to prepare this workflow for user configuration.")
                .font(.system(size: 11.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Close") {
                model.workflowConfigPresented = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x1FB6D1)))
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 320, height: 430)
        .background(Color(hex: 0xF2F2F2))
        .foregroundStyle(Color(hex: 0x222222))
        .preferredColorScheme(.light)
    }

    private var metadataSheet: some View {
        VStack(spacing: 0) {
            ScrollView { workflowInspector }
                .padding(20)
            sheetFooter(help: nil)
        }
        .frame(width: 620, height: 680)
        .background(Color(hex: 0xF2F2F2))
        .foregroundStyle(Color(hex: 0x222222))
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func objectSheet(_ object: WorkflowObject) -> some View {
        if object.kind == .universalAction {
            configuredSheet(width: 640, height: 430, object: object) {
                universalActionForm(object)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else if object.kind == .hotkey {
            configuredSheet(width: 560, height: 500, object: object) {
                HotkeyTriggerForm(model: model, workflowID: workflowID, objectID: object.id)
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        } else {
            let hasScriptFile = !object.scriptFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || object.scriptType == 8
            let height: CGFloat = object.kind == .scriptFilter || hasScriptFile ? 700 : 540
            configuredSheet(width: 980, height: height, object: object) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if object.kind.isSearchInput {
                            HStack(spacing: 12) {
                                field("Keyword", model.bindWorkflowString(workflowID, object.id, "keyword"))
                                field("Placeholder Title", model.bindWorkflowString(workflowID, object.id, "title"))
                            }
                            HStack(spacing: 12) {
                                field("Placeholder Subtext", model.bindWorkflowString(workflowID, object.id, "subtext"))
                                Toggle("Keyword requires a space", isOn: model.bindWorkflowBool(workflowID, object.id, "withspace", default: true))
                                    .toggleStyle(.checkbox)
                            }
                        }
                        if object.kind == .scriptFilter || object.kind == .runScript || object.kind == .appleScript {
                            scriptForm(object)
                        } else {
                            objectFields(object)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private func configuredSheet<Content: View>(width: CGFloat, height: CGFloat, object: WorkflowObject, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
            sheetFooter(help: object)
        }
        .frame(width: width, height: height)
        .background(Color(hex: 0xF2F2F2))
        .foregroundStyle(Color(hex: 0x1D1D1F))
        .preferredColorScheme(.light)
        .presentationBackground(Color(hex: 0xF2F2F2))
    }

    private func sheetFooter(help object: WorkflowObject?) -> some View {
        HStack(spacing: 10) {
            Button {
                model.section = .help
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.plain)
            .help("Help")
            if object != nil, let directory = workflowDirectory {
                Button {
                    NSWorkspace.shared.open(directory)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)
                .help("Open workflow folder")
            }
            Spacer()
            Button("Cancel") { model.cancelWorkflowConfig() }
                .frame(width: 80)
            Button("Save") { model.saveWorkflowConfig() }
                .frame(width: 80)
                .keyboardShortcut(.defaultAction)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(Color(hex: 0xEDEDED))
        .overlay(alignment: .top) { Rectangle().fill(Color.black.opacity(0.12)).frame(height: 1) }
    }

    private var workflowDirectory: URL? {
        guard let workflow, let root = workflow.rootPath else { return nil }
        return URL(fileURLWithPath: root, isDirectory: true)
    }

    @ViewBuilder
    private var inspectorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            workflowInspector
        }
        .padding(18)
        .foregroundStyle(Color(hex: 0x222222))
    }

    @ViewBuilder
    private var workflowInspector: some View {
        Text("Details, variables and hotkey. Select an object to edit its configuration.")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        field("Name", model.bindWorkflow(workflowID, \.name, default: ""))
        Toggle("Enabled", isOn: model.bindWorkflow(workflowID, \.enabled, default: true))
            .toggleStyle(.switch)
            .controlSize(.small)
        field("Keyword", model.bindWorkflow(workflowID, \.keyword, default: ""))
        field("Author", model.bindWorkflow(workflowID, \.author, default: ""))
        field("Description", model.bindWorkflow(workflowID, \.details, default: ""))
        field("SF Symbol", model.bindWorkflow(workflowID, \.symbol, default: "puzzlepiece.extension"))
        field("Tint (hex)", model.bindWorkflow(workflowID, \.tint, default: "561D7E"))
        field("Category", model.bindWorkflow(workflowID, \.category, default: "Uncategorised"))
        field("Website", model.bindWorkflow(workflowID, \.website, default: ""))
        field("Version", model.bindWorkflow(workflowID, \.version, default: "1.0"))
        VStack(alignment: .leading, spacing: 3) {
            Text("Workflow Variables").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            Text("One key=value per line; available as {var:key} and as environment variables.")
                .font(.system(size: 9)).foregroundStyle(.secondary)
            TextEditor(text: model.bindWorkflowVariables(workflowID))
                .font(.system(size: 10, design: .monospaced))
                .frame(height: 70)
                .padding(3)
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 4).fill(.white))
        }
        VStack(alignment: .leading, spacing: 3) {
            Text("Hotkey").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ZStack {
                    if let hotkey = workflow?.hotkey {
                        HotkeyGlyphs(hotkey: hotkey, prominent: false)
                    } else {
                        Text("Click to record").font(.system(size: 10.5)).foregroundStyle(.secondary)
                    }
                    HotkeyCapture(
                        onSet: { code, flags in model.setWorkflowHotkey(workflowID, keyCode: code, modifiers: flags) },
                        onFocus: { focused in
                            if focused { HotkeyCenter.shared.suspend() } else { model.applyHotkeys() }
                        }
                    )
                }
                .frame(width: 145, height: 24)
                .padding(.horizontal, 5)
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 4).fill(.white))
                if workflow?.hotkey != nil {
                    Button("Clear") { model.clearWorkflowHotkey(workflowID) }.controlSize(.small)
                }
            }
        }
        if let workflow, !workflow.website.isEmpty, let url = URL(string: workflow.website) {
            Button("Open Website") { NSWorkspace.shared.open(url) }.controlSize(.small)
        }
        if let workflow, let bundle = workflow.builtin {
            Text("Imported from Alfred · \(bundle)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func objectInspector(_ object: WorkflowObject) -> some View {
        HStack(spacing: 7) {
            if let icon = objectIconImage(object, workflow: workflow) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: object.kind.symbol).font(.system(size: 13))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(object.kind.title).font(.system(size: 13, weight: .semibold))
                Text(object.type).font(.system(size: 8.5, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let index = workflow?.objects.firstIndex(where: { $0.id == object.id }) {
                Toggle("", isOn: Binding(
                    get: { model.debugBreakpoints.contains(index) },
                    set: { model.setBreakpoint(index, $0) }
                ))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .help("Pause at this object")
            }
        }
        if object.kind.isSearchInput {
            field("Keyword", model.bindWorkflowString(workflowID, object.id, "keyword"))
            Toggle("Keyword requires a space", isOn: model.bindWorkflowBool(workflowID, object.id, "withspace", default: true))
                .toggleStyle(.checkbox)
            field("Placeholder title", model.bindWorkflowString(workflowID, object.id, "title"))
            field("Placeholder subtext", model.bindWorkflowString(workflowID, object.id, "subtext"))
        }
        objectFields(object)
        Divider()
        connectionEditor(object)
        Divider()
        HStack(spacing: 8) {
            Button("Duplicate") { model.duplicateWorkflowObject(object.id) }
            Button("Delete", role: .destructive) { model.removeWorkflowObject(object.id) }
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private func scriptForm(_ object: WorkflowObject) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("Language:").font(.system(size: 11.5)).frame(width: 64, alignment: .trailing)
                Picker("", selection: model.bindWorkflowInt(workflowID, object.id, "type", default: 0)) {
                    Text("Bash").tag(0)
                    Text("PHP").tag(1)
                    Text("Ruby").tag(2)
                    Text("Python").tag(3)
                    Text("Perl").tag(4)
                    Text("Zsh").tag(5)
                    Text("AppleScript").tag(6)
                    Text("Swift").tag(7)
                    Text("External Script").tag(8)
                }
                .labelsHidden()
                .frame(width: 160)
                Picker("", selection: model.bindWorkflowInt(workflowID, object.id, "scriptargtype", default: 0)) {
                    Text("with input as {query}").tag(0)
                    Text("with input as argv").tag(1)
                }
                .labelsHidden()
                .frame(width: 180)
                if object.kind == .runScript {
                    Text("running instances").font(.system(size: 11.5))
                    Picker("", selection: concurrencyBinding(object)) {
                        Text("Sequentially").tag(0)
                        Text("Concurrently").tag(1)
                    }
                    .labelsHidden()
                    .frame(width: 135)
                }
                Spacer(minLength: 0)
            }
            let hasScriptFile = !object.scriptFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || object.scriptType == 8
            if hasScriptFile {
                scriptFilePreview(object)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Text("Script:").font(.system(size: 11.5)).frame(width: 64, alignment: .trailing).padding(.top, 2)
                    TextEditor(text: model.bindWorkflowString(workflowID, object.id, "script"))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(minHeight: 360)
                        .padding(3)
                        .scrollContentBackground(.hidden)
                        .background(RoundedRectangle(cornerRadius: 3).fill(.white))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.18)))
                }
            }
            if object.kind == .scriptFilter {
                HStack(spacing: 16) {
                    Toggle("Alfred filters results", isOn: model.bindWorkflowBool(workflowID, object.id, "alfredfiltersresults"))
                        .toggleStyle(.checkbox)
                    if model.workflows.first(where: { $0.id == workflowID })?.object(id: object.id)?.filtersResults == true {
                        matchModePicker(object)
                            .frame(width: 220)
                    }
                }
                Picker("Argument requirement", selection: model.bindWorkflowInt(workflowID, object.id, "argumenttype", default: 0)) {
                    Text("Optional").tag(0)
                    Text("Required").tag(1)
                    Text("No argument").tag(2)
                }
                .frame(width: 320)
            }
            Text("Environment includes alfred_workflow_* and workflow variables. Relative paths start at the workflow folder.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func scriptFilePreview(_ object: WorkflowObject) -> some View {
        let url = resolvedScriptFileURL(object)
        HStack(spacing: 8) {
            Text("Script File:").font(.system(size: 11.5)).frame(width: 78, alignment: .trailing)
            TextField("Script file", text: model.bindWorkflowString(workflowID, object.id, "scriptfile"))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11.5))
            Button("Open File") {
                if let url { NSWorkspace.shared.open(url) }
            }
            .disabled(url == nil)
        }
        Text(scriptFileCaption(object))
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
            .padding(.leading, 86)
        ScriptFilePreview(text: scriptFileContents(at: url))
            .frame(minHeight: 360)
    }

    private func scriptFileCaption(_ object: WorkflowObject) -> String {
        let input = object.scriptArgumentType == 1
            ? "The input is passed to the script as argv."
            : "The {query} placeholder is replaced with the input."
        return "Scripts are run relative to the workflow folder. \(input)"
    }

    private func resolvedScriptFileURL(_ object: WorkflowObject) -> URL? {
        let raw = object.scriptFile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let expanded = (raw as NSString).expandingTildeInPath
        let url: URL
        if expanded.hasPrefix("/") {
            url = URL(fileURLWithPath: expanded)
        } else if let directory = workflowDirectory {
            url = directory.appendingPathComponent(expanded)
        } else {
            return nil
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { return nil }
        return url
    }

    private func scriptFileContents(at url: URL?) -> String {
        guard let url, let data = try? Data(contentsOf: url) else { return "" }
        if let text = String(data: data, encoding: .utf8) { return text }
        return String(data: data, encoding: .utf16) ?? ""
    }

    private func concurrencyBinding(_ object: WorkflowObject) -> Binding<Int> {
        let binding = model.bindWorkflowBool(workflowID, object.id, "concurrently")
        return Binding(
            get: { binding.wrappedValue ? 1 : 0 },
            set: { binding.wrappedValue = ($0 == 1) }
        )
    }

    @ViewBuilder
    private func objectFields(_ object: WorkflowObject) -> some View {
        switch object.kind {
        case .keyword, .listFilter, .externalTriggerInput:
            if object.kind == .listFilter {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Items JSON").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    TextEditor(text: model.bindWorkflowString(workflowID, object.id, "items"))
                        .font(.system(size: 10, design: .monospaced))
                        .frame(height: 150)
                        .padding(3)
                        .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 4).fill(.white))
                }
            }
            if object.kind == .externalTriggerInput {
                field("Trigger ID", model.bindWorkflowString(workflowID, object.id, "triggerid"))
            }

        case .scriptFilter, .runScript, .appleScript:
            scriptFields(object)

        case .openURL:
            field("URL", model.bindWorkflowString(workflowID, object.id, "url"))
            Text("Use {query} for the typed text.").font(.system(size: 9)).foregroundStyle(.secondary)

        case .openFile, .revealFile:
            field("Path", model.bindWorkflowString(workflowID, object.id, "path"))

        case .clipboard:
            field("Text", model.bindWorkflowString(workflowID, object.id, "clipboardtext"))
            Toggle("Auto-paste after copying", isOn: model.bindWorkflowBool(workflowID, object.id, "autopaste"))
                .toggleStyle(.checkbox)

        case .largeType, .speak:
            field("Text", model.bindWorkflowString(workflowID, object.id, "text"))

        case .notification:
            field("Title", model.bindWorkflowString(workflowID, object.id, "title"))
            field("Text", model.bindWorkflowString(workflowID, object.id, "text"))

        case .playSound:
            field("Sound file", model.bindWorkflowString(workflowID, object.id, "path"))

        case .terminal:
            field("Command", model.bindWorkflowString(workflowID, object.id, "command"))

        case .argument:
            field("Argument", model.bindWorkflowString(workflowID, object.id, "argument"))
            Toggle("Pass through incoming argument", isOn: model.bindWorkflowBool(workflowID, object.id, "passthroughargument"))
                .toggleStyle(.checkbox)
            VStack(alignment: .leading, spacing: 3) {
                Text("Variables").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                TextEditor(text: model.bindWorkflowVariables(workflowID, object.id))
                    .font(.system(size: 10, design: .monospaced))
                    .frame(height: 82)
                    .padding(3)
                    .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 4).fill(.white))
            }

        case .filter:
            field("Input", model.bindWorkflowString(workflowID, object.id, "inputstring"))
            field("Match", model.bindWorkflowString(workflowID, object.id, "matchstring"))
            matchModePicker(object)

        case .conditional:
            conditionalFields(object)

        case .delay:
            HStack {
                Text("Seconds").font(.system(size: 10))
                TextField("0.5", value: Binding(
                    get: { object.config["seconds"]?.doubleValue ?? 0.5 },
                    set: { model.setWorkflowDelay(object.id, $0) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            }

        case .debug:
            field("Message", model.bindWorkflowString(workflowID, object.id, "text"))

        case .writeFile:
            field("Path", model.bindWorkflowString(workflowID, object.id, "path"))
            field("Content", model.bindWorkflowString(workflowID, object.id, "text"))

        case .hotkey, .universalAction:
            EmptyView()

        case .junction:
            Text("Passes its input to every connected object.")
                .font(.system(size: 10)).foregroundStyle(.secondary)

        case .externalTrigger:
            field("Trigger ID", model.bindWorkflowString(workflowID, object.id, "triggerid"))

        case .automationTask:
            Text("Alfred Automation Task").font(.system(size: 11, weight: .semibold))
            Text(object.config[string: "taskuid"])
                .font(.system(size: 9, design: .monospaced))
                .textSelection(.enabled)
            Text("Jfred imports this object for graph fidelity but cannot run Alfred's private Automation Task runtime.")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)

        case .textView:
            field("File", model.bindWorkflowString(workflowID, object.id, "inputfile"))

        case .userInterface, .unknown:
            Text("This object type is preserved but not executable in Jfred.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func scriptFields(_ object: WorkflowObject) -> some View {
        Picker("Language", selection: model.bindWorkflowInt(workflowID, object.id, "type", default: 0)) {
            Text("Bash").tag(0)
            Text("PHP").tag(1)
            Text("Ruby").tag(2)
            Text("Python").tag(3)
            Text("Perl").tag(4)
            Text("Zsh").tag(5)
            Text("AppleScript").tag(6)
            Text("Swift").tag(7)
        }
        .font(.system(size: 11))
        Picker("Argument", selection: model.bindWorkflowInt(workflowID, object.id, "scriptargtype", default: 0)) {
            Text("Replace {query}").tag(0)
            Text("Pass as argv").tag(1)
        }
        .font(.system(size: 11))
        VStack(alignment: .leading, spacing: 3) {
            Text("Script").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            TextEditor(text: model.bindWorkflowString(workflowID, object.id, "script"))
                .font(.system(size: 10, design: .monospaced))
                .frame(height: 170)
                .padding(3)
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 4).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.12)))
        }
        field("Script file", model.bindWorkflowString(workflowID, object.id, "scriptfile"))
        if object.kind == .scriptFilter {
            Toggle("Alfred filters results", isOn: model.bindWorkflowBool(workflowID, object.id, "alfredfiltersresults"))
                .toggleStyle(.checkbox)
            matchModePicker(object)
            Picker("Argument requirement", selection: model.bindWorkflowInt(workflowID, object.id, "argumenttype", default: 0)) {
                Text("Optional").tag(0)
                Text("Required").tag(1)
                Text("No argument").tag(2)
            }
            .font(.system(size: 11))
        }
        Text("Environment includes alfred_workflow_* and workflow variables. Relative paths start at the workflow folder.")
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func matchModePicker(_ object: WorkflowObject) -> some View {
        Picker("Match mode", selection: model.bindWorkflowInt(workflowID, object.id, "alfredfiltersresultsmatchmode", default: 0)) {
            Text("Exact from word start").tag(0)
            Text("Exact from start").tag(1)
            Text("Words, any order").tag(2)
            Text("Words, sequential").tag(3)
        }
        .font(.system(size: 11))
    }

    @ViewBuilder
    private func conditionalFields(_ object: WorkflowObject) -> some View {
        let conditions = object.config["conditions"]?.arrayValue ?? []
        if conditions.isEmpty {
            Text("No conditions. This object acts as a pass-through.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        } else {
            ForEach(Array(conditions.indices), id: \.self) { index in
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.workflowConditionLabel(workflowID, object.id, index))
                        .font(.system(size: 10, weight: .semibold))
                    TextField("Input", text: model.bindWorkflowConditionString(workflowID, object.id, index, "inputstring"))
                        .textFieldStyle(.roundedBorder)
                    TextField("Match", text: model.bindWorkflowConditionString(workflowID, object.id, index, "matchstring"))
                        .textFieldStyle(.roundedBorder)
                    Picker("Go to", selection: branchBinding(source: object.id, sourceOutputUID: conditionUID(conditions[index]))) {
                        Text("None").tag(UUID?.none)
                        ForEach(destinations(for: object), id: \.id) { destination in
                            Text(destination.title).tag(Optional(destination.id))
                        }
                    }
                    .font(.system(size: 10))
                }
                .padding(6)
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 5).fill(.white))
            }
        }
    }

    private func conditionUID(_ value: WorkflowValue) -> String {
        value.objectValue?[string: "uid"] ?? ""
    }

    @ViewBuilder
    private func connectionEditor(_ object: WorkflowObject) -> some View {
        Text("Connections").font(.system(size: 11, weight: .semibold))
        Picker(object.kind == .conditional ? "Otherwise" : "Next", selection: destinationBinding(source: object.id, modifiers: 0)) {
            Text("None").tag(UUID?.none)
            ForEach(destinations(for: object), id: \.id) { destination in
                Text(destination.title).tag(Optional(destination.id))
            }
        }
        .font(.system(size: 10.5))
        if object.kind != .conditional {
            ForEach(modifierOptions, id: \.0) { modifier, label in
                Picker(label, selection: destinationBinding(source: object.id, modifiers: modifier)) {
                    Text("None").tag(UUID?.none)
                    ForEach(destinations(for: object), id: \.id) { destination in
                        Text(destination.title).tag(Optional(destination.id))
                    }
                }
                .font(.system(size: 10.5))
            }
        }
        if object.kind == .junction {
            Text("Junction sends to every non-modifier connection, not just the first.")
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    private var modifierOptions: [(Int, String)] {
        [
            (Int(Hotkey.command), "⌘ Next"),
            (Int(Hotkey.option), "⌥ Next"),
            (Int(Hotkey.control), "⌃ Next"),
            (Int(Hotkey.shift), "⇧ Next"),
        ]
    }

    private func destinations(for object: WorkflowObject) -> [WorkflowObject] {
        (workflow?.objects ?? []).filter { $0.id != object.id }
    }

    private func destinationBinding(source: UUID, modifiers: Int) -> Binding<UUID?> {
        Binding(
            get: { model.workflowDestination(source: source, modifiers: modifiers) },
            set: { model.setWorkflowDestination(source: source, modifiers: modifiers, destination: $0) }
        )
    }

    private func branchBinding(source: UUID, sourceOutputUID: String) -> Binding<UUID?> {
        Binding(
            get: { model.workflowBranchDestination(source: source, sourceOutputUID: sourceOutputUID) },
            set: { model.setWorkflowBranchDestination(source: source, sourceOutputUID: sourceOutputUID, destination: $0) }
        )
    }

    private func field(_ title: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 10.5, weight: .medium)).foregroundStyle(.secondary)
            TextField(title, text: binding)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11.5))
        }
    }

    private var tintColor: Color {
        Color(hex: UInt32(workflow?.tint ?? "561D7E", radix: 16) ?? 0x561D7E)
    }

    private func exportCurrentWorkflow() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (workflow?.name ?? "Workflow").replacingOccurrences(of: "/", with: "-") + ".jfred-workflow.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url, let workflow else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(workflow) else { return }
        try? data.write(to: url, options: .atomic)
    }

    @ViewBuilder
    private var debuggerPane: some View {
        if model.debuggerVisible {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "ladybug")
                        .font(.system(size: 11))
                        .foregroundStyle(WorkflowChrome.secondary)
                    Text("Debugger")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(WorkflowChrome.primary)
                    TextField("Test query", text: model.bind(\.debugQuery))
                        .textFieldStyle(.plain)
                        .font(.system(size: 10.5))
                        .padding(.horizontal, 5)
                        .frame(width: 150, height: 20)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white))
                        .foregroundStyle(WorkflowChrome.primary)
                    Button("Run") { model.runWorkflowDebug(workflowID) }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5))
                    Button("Step") { model.stepWorkflowDebug(workflowID) }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5))
                    Spacer()
                    Text("All Information").font(.system(size: 10)).foregroundStyle(.secondary)
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(model.debugLines.joined(separator: "\n"), forType: .string)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    Button("Clear") { model.debugLines = [] }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                    Button("Close") { model.debuggerVisible = false }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(WorkflowChrome.rail)
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(model.debugLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(WorkflowChrome.primary.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .frame(height: 76)
                .background(WorkflowChrome.well)
            }
            .overlay(alignment: .top) { Rectangle().fill(WorkflowChrome.hairline).frame(height: 1) }
        } else {
            Button {
                model.debuggerVisible = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "ladybug")
                        .font(.system(size: 11))
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                    Text("Debugger Stopped")
                        .font(.system(size: 10.5))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(WorkflowChrome.rail)
                .overlay(alignment: .top) { Rectangle().fill(WorkflowChrome.hairline).frame(height: 1) }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func universalActionForm(_ object: WorkflowObject) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Name:")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0x1D1D1F))
                        .frame(width: 72, alignment: .trailing)
                    TextField("Name", text: model.bindWorkflowString(workflowID, object.id, "name"))
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(Color(hex: 0x1D1D1F))
                }
                Text("The searchable name for the Universal Actions view.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0x6E6E73))
                    .padding(.leading, 80)
                HStack(spacing: 10) {
                    Text("Show for:")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0x1D1D1F))
                        .frame(width: 72, alignment: .trailing)
                    Toggle("Files", isOn: model.bindWorkflowBool(workflowID, object.id, "acceptsfiles"))
                        .toggleStyle(.checkbox)
                    Toggle("URLs", isOn: model.bindWorkflowBool(workflowID, object.id, "acceptsurls"))
                        .toggleStyle(.checkbox)
                    Toggle("Text", isOn: model.bindWorkflowBool(workflowID, object.id, "acceptstext"))
                        .toggleStyle(.checkbox)
                }
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: 0x1D1D1F))
                Text("Only show this trigger when the input argument matches the type.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0x6E6E73))
                    .padding(.leading, 80)
                HStack(spacing: 8) {
                    Text("")
                        .frame(width: 72)
                    Picker("", selection: model.bindWorkflowInt(workflowID, object.id, "acceptsmulti")) {
                        ForEach(Array(WorkflowTriggerLabels.universalArgumentCounts.enumerated()), id: \.offset) { index, title in
                            Text(title).tag(index)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                    Text("Input Arguments")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0x1D1D1F))
                }
                Text("Select the multiple argument capability of this trigger.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0x6E6E73))
                    .padding(.leading, 80)
                Text("Note: You can prevent Keyword and Script Filter inputs in this workflow from being automatically treated as Universal Actions by unchecking the \"Treat Input as Universal Action\" option in the pop-up menu for the selected inputs.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0x6E6E73))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.08)))
                    .padding(.top, 6)
            }
            VStack(spacing: 6) {
                universalActionIconWell(object)
                Text("Drop an icon above.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0x6E6E73))
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
            .padding(.top, 2)
        }
    }

    private func universalActionIconWell(_ object: WorkflowObject) -> some View {
        let configured = object.config[string: "icon"]
        let image: NSImage? = {
            guard !configured.isEmpty, let workflow else { return nil }
            return artworkImage(from: WorkflowIcon.resolve(
                path: configured,
                workflowRoot: workflow.rootPath,
                workflowSymbol: workflow.symbol,
                objectUID: object.alfredUID
            ))
        }()
        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(6)
            }
        }
        .frame(width: 70, height: 70)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.15)))
        .onTapGesture { chooseUniversalActionIcon(object) }
        .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
            loadUniversalActionIcon(object, providers)
            return true
        }
        .help("Drop an icon above.")
    }

    private func chooseUniversalActionIcon(_ object: WorkflowObject) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .icns]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.setWorkflowObjectIcon(workflowID, object.id, from: url)
    }

    private func loadUniversalActionIcon(_ object: WorkflowObject, _ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let item = item as? URL {
                url = item
            } else if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = nil
            }
            guard let url else { return }
            DispatchQueue.main.async {
                model.setWorkflowObjectIcon(workflowID, object.id, from: url)
            }
        }
    }

}

private struct HotkeyTriggerForm: View {
    var model: AppModel
    var workflowID: UUID
    var objectID: UUID
    @State private var tab = 0
    @State private var selectedBundle = ""

    private var object: WorkflowObject? {
        model.workflows.first { $0.id == workflowID }?.object(id: objectID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $tab) {
                Text("Hotkey Settings").tag(0)
                Text("Related Apps").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 280)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)

            if tab == 0 {
                settings
            } else {
                relatedApps
            }
            Spacer(minLength: 0)
        }
    }

    private var settings: some View {
        let code = object?.config["hotkey"]?.intValue ?? 0
        let modifiers = UInt(truncatingIfNeeded: object?.config["hotmod"]?.intValue ?? 0)
        let argument = object?.config[integer: "argument"] ?? 0
        let action = object?.config[integer: "action"] ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            labeled("Hotkey:") {
                HStack(spacing: 6) {
                    ZStack {
                        if code != 0 {
                            HotkeyGlyphs(hotkey: Hotkey(keyCode: UInt16(truncatingIfNeeded: code), modifiers: modifiers), prominent: false)
                        } else {
                            Text("Click to record")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: 0x8E8E93))
                        }
                        HotkeyCapture(
                            onSet: { keyCode, flags in
                                model.setWorkflowObjectHotkey(workflowID, objectID, keyCode: keyCode, modifiers: flags, display: keyDisplayName(keyCode))
                            },
                            onFocus: { focused in
                                if focused { HotkeyCenter.shared.suspend() } else { model.applyHotkeys() }
                            }
                        )
                    }
                    .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: 0x8AB4F8), lineWidth: 1))
                    Menu {
                        ForEach(Array(WorkflowTriggerLabels.hotkeyModifierModes.enumerated()), id: \.offset) { index, title in
                            Button(title) { model.bindWorkflowInt(workflowID, objectID, "modsmode").wrappedValue = index }
                        }
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 11))
                            .frame(width: 22, height: 22)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                    .help(WorkflowTriggerLabels.hotkeyModifierModes[min(max(object?.config[integer: "modsmode"] ?? 0, 0), WorkflowTriggerLabels.hotkeyModifierModes.count - 1)])
                    if code != 0 {
                        Button("Clear") { model.clearWorkflowObjectHotkey(workflowID, objectID) }
                            .controlSize(.small)
                    }
                }
            }
            hint("The hotkey combination you would like to use to trigger this workflow object.")

            labeled("Action:") {
                menuPicker(WorkflowTriggerLabels.hotkeyActions, model.bindWorkflowInt(workflowID, objectID, "action"))
            }
            hint("What to do when the hotkey is pressed. Note that if you choose 'Show Alfred', nothing will be passed out from the output of this processor, even if connected.")

            labeled("Argument:") {
                menuPicker(WorkflowTriggerLabels.hotkeyArguments, model.bindWorkflowInt(workflowID, objectID, "argument", default: 1))
            }
            if argument != 0 {
                labeled(argument == 4 ? "Text:" : "Prefix:") {
                    HStack(spacing: 8) {
                        TextField("", text: model.bindWorkflowString(workflowID, objectID, "argumenttext"))
                            .textFieldStyle(.roundedBorder)
                            .foregroundStyle(Color(hex: 0x1D1D1F))
                        if action == 1 {
                            Text("Cursor:")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: 0x1D1D1F))
                            Picker("", selection: cursorBinding) {
                                Text("Right").tag(false)
                                Text("Left").tag(true)
                            }
                            .labelsHidden()
                            .frame(width: 90)
                        }
                    }
                }
                hint("An optional argument to be used. If text is input, this will be prefixed onto the dynamic argument types.")
            }
        }
    }

    private var relatedApps: some View {
        let apps = object?.relatedApps ?? []
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Hotkey is only active when the following apps")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0x1D1D1F))
                menuPicker(WorkflowTriggerLabels.relatedAppModes, model.bindWorkflowInt(workflowID, objectID, "relatedAppsMode"))
                    .frame(width: 150)
            }
            HStack(alignment: .top, spacing: 8) {
                ScrollView {
                    VStack(spacing: 0) {
                        if apps.isEmpty {
                            Text("Drop apps (e.g. from Finder or Alfred's results) above to add them.")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: 0x6E6E73))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        ForEach(apps) { app in
                            HStack(spacing: 6) {
                                Image(nsImage: applicationIcon(app.bundleID))
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                Text(app.name)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: 0x1D1D1F))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(app.bundleID)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: 0x6E6E73))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .frame(height: 24)
                            .background(selectedBundle == app.bundleID ? Color(hex: 0xD6E8F8) : Color.white)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedBundle = app.bundleID }
                        }
                    }
                }
                .frame(height: 150)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.15)))
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    loadDroppedApps(providers)
                    return true
                }
                VStack(spacing: 6) {
                    Button {
                        chooseApps()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 22, height: 22)
                    }
                    .help("Add an application to this hotkey's related apps")
                    Button {
                        removeSelectedApp()
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 22, height: 22)
                    }
                    .disabled(selectedBundle.isEmpty)
                    .help("Remove selected applications from this hotkey's related apps")
                }
            }
            Toggle("Focused App Variable:", isOn: model.bindWorkflowBool(workflowID, objectID, "focusedappvariable"))
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: 0x1D1D1F))
            TextField("focusedapp", text: model.bindWorkflowString(workflowID, objectID, "focusedappvariablename"))
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(Color(hex: 0x1D1D1F))
                .disabled(!(object?.config["focusedappvariable"]?.boolValue ?? false))
            hint("Set a variable with the bundle id of the focused app when this hotkey was triggered.")
        }
    }

    private var cursorBinding: Binding<Bool> {
        model.bindWorkflowBool(workflowID, objectID, "leftcursor")
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: 0x1D1D1F))
                .frame(width: 72, alignment: .trailing)
            content()
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Color(hex: 0x6E6E73))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 80)
    }

    private func menuPicker(_ titles: [String], _ selection: Binding<Int>) -> some View {
        Picker("", selection: selection) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Text(title).tag(index)
            }
        }
        .labelsHidden()
        .frame(maxWidth: 280)
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        addApps(panel.urls)
    }

    private func loadDroppedApps(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let item = item as? URL {
                    url = item
                } else if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = nil
                }
                guard let url else { return }
                DispatchQueue.main.async { addApps([url]) }
            }
        }
    }

    private func addApps(_ urls: [URL]) {
        var apps = object?.relatedApps ?? []
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard url.pathExtension.lowercased() == "app" || Bundle(url: url) != nil else { continue }
            let bundleID = Bundle(url: url)?.bundleIdentifier ?? ""
            guard !bundleID.isEmpty, !apps.contains(where: { $0.bundleID == bundleID }) else { continue }
            let name = FileManager.default.displayName(atPath: url.path)
            apps.append(WorkflowRelatedApp(name: name, bundleID: bundleID))
        }
        model.setWorkflowRelatedApps(workflowID, objectID, apps)
    }

    private func removeSelectedApp() {
        guard !selectedBundle.isEmpty else { return }
        let apps = (object?.relatedApps ?? []).filter { $0.bundleID != selectedBundle }
        selectedBundle = ""
        model.setWorkflowRelatedApps(workflowID, objectID, apps)
    }

    private func applicationIcon(_ bundleID: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }
}

private extension WorkflowObjectKind {
    var paletteDetail: String {
        switch self {
        case .keyword: return "Use a keyword to start a workflow."
        case .scriptFilter: return "Dynamically populate results with a script."
        case .listFilter: return "A fixed list filtered locally."
        case .runScript: return "Run commands in macOS using any language."
        case .appleScript: return "Control another app with AppleScript."
        case .terminal: return "Run a command in Terminal."
        case .openURL: return "Open a URL in the default browser."
        case .openFile: return "Open a file or application."
        case .revealFile: return "Reveal a file in Finder."
        case .clipboard: return "Copy text to the clipboard."
        case .largeType: return "Show text in large type."
        case .notification: return "Post a macOS notification."
        case .playSound: return "Play a sound file."
        case .speak: return "Speak text aloud."
        case .argument: return "Set the argument and workflow variables."
        case .conditional: return "Branch depending on a condition."
        case .filter: return "Filter the stream with a rule."
        case .junction: return "Combine or split workflow streams."
        case .delay: return "Pause before the next object."
        case .debug: return "Write a message to the debugger."
        case .writeFile: return "Write text to a file."
        case .externalTrigger: return "Call an external trigger."
        case .externalTriggerInput: return "Start with an external trigger."
        case .hotkey: return "Start with a keyboard shortcut."
        case .universalAction: return "Show this workflow in Universal Actions."
        case .automationTask: return "Run an Alfred Automation Task."
        case .textView: return "Show text in a window."
        case .userInterface: return "Show a user interface object."
        case .unknown: return "Unknown object."
        }
    }
}


private enum WorkflowImportPanel {
    static var allowedTypes: [UTType] {
        var types: [UTType] = [.zip]
        if let type = UTType("com.runningwithcrayons.alfred.workflow") {
            types.insert(type, at: 0)
        }
        if let type = UTType(filenameExtension: "alfredworkflow") {
            types.insert(type, at: 0)
        }
        return types
    }
}
