import AppKit
import SwiftUI
import JfredCore
import UniformTypeIdentifiers

struct WorkflowsPane: View {
    var model: AppModel

    private var visible: [Workflow] {
        let q = model.workflowFilter.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return model.workflows }
        return model.workflows.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.keyword.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                list
                if let id = model.selectedWorkflow, model.workflows.contains(where: { $0.id == id }) {
                    WorkflowEditor(model: model, workflowID: id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    cards
                }
            }
            footer
        }
        .sheet(isPresented: model.bind(\.showTemplates)) { templateSheet }
        .background(Color(hex: 0x1B1B1B))
    }

    private var list: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Filter", text: model.bind(\.workflowFilter)).textFieldStyle(.plain)
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.92)))
            .padding(8)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(visible) { workflow in
                        Button {
                            if model.editingWorkflowID != nil { model.saveWorkflowEdit() }
                            model.beginWorkflowEdit(workflow)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: workflow.symbol)
                                    .frame(width: 28, height: 28)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: UInt32(Int(workflow.tint, radix: 16) ?? 0x666666))))
                                    .foregroundStyle(.white)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(workflow.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                    Text("by \(workflow.author)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.82))
                                }
                                Spacer()
                            }
                            .opacity(workflow.enabled ? 1 : 0.45)
                            .saturation(workflow.enabled ? 1 : 0.2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .foregroundStyle(.white)
                            .background(model.selectedWorkflow == workflow.id ? Color.white.opacity(0.22) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu { workflowMenu(workflow) }
                    }
                }
            }
        }
        .frame(width: 240)
        .background(Color(hex: 0x2F104B))
    }

    @ViewBuilder
    private func workflowMenu(_ workflow: Workflow) -> some View {
        Toggle("Enabled", isOn: model.bindWorkflow(workflow.id, \.enabled, default: false))
        Divider()
        Button("Configure…") { model.beginWorkflowEdit(workflow) }
        Button("Edit Details…") { model.beginWorkflowEdit(workflow) }
        Divider()
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
        Button("Export…") { export(workflow, metadataOnly: false) }
        Button("Export Metadata…") { export(workflow, metadataOnly: true) }
        Button("Reload Workflows") { model.reloadWorkflowsFromAlfred() }
        Divider()
        Button("Import Workflow…") { chooseWorkflowToImport() }
        Button("Import from Alfred Library…") { model.importAlfredLibrary() }
        Button("Delete", role: .destructive) {
            model.workflows.removeAll { $0.id == workflow.id }
            if model.selectedWorkflow == workflow.id {
                model.selectedWorkflow = model.workflows.first?.id
            }
        }
    }

    private func chooseWorkflowToImport() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let type = UTType(filenameExtension: "alfredworkflow") {
            panel.allowedContentTypes = [type]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.importWorkflow(at: url)
    }

    private func export(_ workflow: Workflow, metadataOnly: Bool) {
        let panel = NSSavePanel()
        let base = workflow.name.replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = base + (metadataOnly ? " Metadata.json" : ".json")
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data: Data?
        if metadataOnly {
            let metadata: [String: Any] = [
                "name": workflow.name,
                "keyword": workflow.keyword,
                "author": workflow.author,
                "symbol": workflow.symbol,
                "tint": workflow.tint,
                "enabled": workflow.enabled,
            ]
            data = try? JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        } else {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            data = try? encoder.encode(workflow)
        }
        guard let data else { return }
        try? data.write(to: url, options: .atomic)
    }

    private var cards: some View {
        ScrollView {
            VStack(spacing: 12) {
                card("sparkles", "Alfred Gallery", "Browse the Alfred Gallery and install community workflows.") {
                    if let url = URL(string: "https://alfred.app/") { NSWorkspace.shared.open(url) }
                }
                card("book", "Getting Started Guide", "Check out the guide to learn the basics.") { model.section = .help }
                card("point.3.connected.trianglepath.dotted", "Create a new Workflow", "Jump in and create a blank Workflow.") { model.beginWorkflowEdit(blank()) }
                card("square.on.square", "Create a Workflow from a Template", "New to workflows? Try one of our Getting Started templates.") { model.showTemplates = true }
                card("doc.text", "View Documentation", "Find out more about how to configure and use workflow objects.") { model.section = .help }
            }
            .frame(maxWidth: 760)
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func card(_ symbol: String, _ title: String, _ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .light))
                    .frame(width: 62)
                    .foregroundStyle(.white.opacity(0.9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.52))
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 78)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x2B2B2B)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Alfred Gallery") {
                if let url = URL(string: "https://alfred.app/") { NSWorkspace.shared.open(url) }
            }
            Button("Help") { model.section = .help }
            Button("+") { model.beginWorkflowEdit(blank()) }
            Button("−") {
                guard let id = model.selectedWorkflow else { return }
                model.workflows.removeAll { $0.id == id }
                model.selectedWorkflow = model.workflows.first?.id
            }
            Button("Import…") { chooseWorkflowToImport() }
            Spacer()
            Text(model.debugLine.isEmpty ? "Debugger Stopped" : model.debugLine)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color(hex: 0x2A2A2A))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
        .foregroundStyle(.white)
    }

    private func blank() -> Workflow {
        Workflow(name: "Untitled Workflow", keyword: "do", author: "You", symbol: "bolt.fill", tint: "561D7E", actions: [WorkflowAction(kind: .copy, value: "{query}")])
    }

    private var templateSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Templates").font(.title3)
            template("Web search", "keyword opens a URL", [WorkflowAction(kind: .openURL, value: "https://www.google.com/search?q={query}")], "g2", "magnifyingglass")
            template("Shell script", "run a command", [WorkflowAction(kind: .shell, value: "echo {query}")], "sh", "terminal")
            template("Open application", "launch an app by name or path", [WorkflowAction(kind: .openApp, value: "Notes")], "app", "macwindow")
            template("AppleScript", "control a Mac app", [WorkflowAction(kind: .appleScript, value: "tell application \"Finder\" to activate")], "as", "applescript")
            Button("Close") { model.showTemplates = false }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func template(_ name: String, _ detail: String, _ actions: [WorkflowAction], _ keyword: String, _ symbol: String) -> some View {
        Button {
            let workflow = Workflow(name: name, keyword: keyword, author: "You", symbol: symbol, tint: "561D7E", actions: actions)
            model.showTemplates = false
            model.beginWorkflowEdit(workflow)
        } label: {
            VStack(alignment: .leading) {
                Text(name).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

}

struct WorkflowEditor: View {
    var model: AppModel
    var workflowID: UUID

    private var workflow: Workflow? {
        model.workflows.first { $0.id == workflowID }
    }

    private var actions: [WorkflowAction] { workflow?.actions ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                palette
                canvas
                inspector
            }
            if model.debuggerVisible { debuggerPane }
            footer
        }
        .frame(minWidth: 680, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
        .background(Color(hex: 0x1B1B1B))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: workflow?.symbol ?? "bolt.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: UInt32(Int(workflow?.tint ?? "561D7E", radix: 16) ?? 0x561D7E))))
            VStack(alignment: .leading, spacing: 1) {
                Text(workflow?.name ?? "Workflow").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text("Keyword: \(workflow?.keyword ?? "")").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Toggle("Enabled", isOn: model.bindWorkflow(workflowID, \.enabled, default: false))
                .toggleStyle(.switch)
                .controlSize(.small)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color(hex: 0x2A2A2A))
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Objects")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 4)
            ForEach(WorkflowAction.Kind.allCases, id: \.self) { kind in
                Button {
                    appendAction(kind)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: symbol(for: kind))
                            .font(.system(size: 11))
                            .frame(width: 16)
                        Text(label(for: kind))
                            .font(.system(size: 11))
                            .lineLimit(1)
                        Spacer()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(width: 150)
        .background(Color(hex: 0x242424))
    }

    private var canvas: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(spacing: 0) {
                node(
                    icon: "keyboard",
                    title: "Keyword",
                    subtitle: workflow?.keyword ?? "",
                    selected: model.workflowSelection == nil
                ) { model.workflowSelection = nil }
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    connector
                    node(
                        icon: symbol(for: action.kind),
                        title: label(for: action.kind),
                        subtitle: action.value,
                        selected: model.workflowSelection == index,
                        breakpoint: model.debugBreakpoints.contains(index)
                    ) { model.workflowSelection = index }
                    .onDrag {
                        model.workflowSelection = index
                        model.workflowDragIndex = index
                        return NSItemProvider(object: "\(index)" as NSString)
                    }
                    .onDrop(of: [.text], delegate: WorkflowDropDelegate(model: model, target: index))
                }
                connector
                Menu {
                    ForEach(WorkflowAction.Kind.allCases, id: \.self) { kind in
                        Button(label(for: kind)) { appendAction(kind) }
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 18))
                        Text("Add Action").font(.system(size: 11))
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 110, height: 104)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4])))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0x1E1E1E))
    }

    private var connector: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.28))
            .frame(width: 34)
    }

    private func node(icon: String, title: String, subtitle: String, selected: Bool, breakpoint: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon).font(.system(size: 14))
                    Spacer()
                }
                Text(title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text(subtitle.isEmpty ? "No value" : subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(10)
            .frame(width: 170, height: 110, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color(hex: 0x3C2350) : Color(hex: 0x2B2B2B)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color(hex: 0x8E5AB5) : Color.white.opacity(0.08), lineWidth: selected ? 1.5 : 1))
            .overlay(alignment: .topTrailing) {
                if breakpoint {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var inspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.workflowSelection == nil ? "Workflow" : "Object")
                .font(.system(size: 14, weight: .semibold))
            if let index = model.workflowSelection, actions.indices.contains(index) {
                Picker("Type", selection: model.bindAction(workflowID, index, \.kind, default: .copy)) {
                    ForEach(WorkflowAction.Kind.allCases, id: \.self) { kind in
                        Text(label(for: kind)).tag(kind)
                    }
                }
                TextEditor(text: model.bindAction(workflowID, index, \.value, default: ""))
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 140)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.15)))
                Text("Use {query} for the text typed after the keyword.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("← Move Left") { moveAction(index, -1) }
                        .disabled(index == 0)
                    Button("Move Right →") { moveAction(index, 1) }
                        .disabled(index >= actions.count - 1)
                }
                .controlSize(.small)
                Toggle("Pause at this action", isOn: Binding(
                    get: { model.debugBreakpoints.contains(index) },
                    set: { model.setBreakpoint(index, $0) }
                ))
                .toggleStyle(.checkbox)
                HStack(spacing: 8) {
                    Button("Duplicate Object") { model.duplicateWorkflowAction(index) }
                    Button("Remove Object", role: .destructive) { removeAction(index) }
                }
            } else {
                field("Name", model.bindWorkflow(workflowID, \.name, default: ""))
                field("Keyword", model.bindWorkflow(workflowID, \.keyword, default: ""))
                field("Author", model.bindWorkflow(workflowID, \.author, default: ""))
                field("SF Symbol", model.bindWorkflow(workflowID, \.symbol, default: "bolt.fill"))
                field("Tint (hex)", model.bindWorkflow(workflowID, \.tint, default: "561D7E"))
                Toggle("Enabled", isOn: model.bindWorkflow(workflowID, \.enabled, default: false))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hotkey")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ZStack {
                            if let hotkey = workflow?.hotkey {
                                HotkeyGlyphs(hotkey: hotkey, prominent: false)
                            } else {
                                Text("Click to record")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            HotkeyCapture(
                                onSet: { code, flags in model.setWorkflowHotkey(workflowID, keyCode: code, modifiers: flags) },
                                onFocus: { focused in
                                    if focused { HotkeyCenter.shared.suspend() } else { model.applyHotkeys() }
                                }
                            )
                        }
                        .frame(width: 150, height: 24)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.12)))
                        if workflow?.hotkey != nil {
                            Button("Clear") { model.clearWorkflowHotkey(workflowID) }
                                .controlSize(.small)
                        }
                    }
                }
            }
            Spacer()
        }
        .textFieldStyle(.roundedBorder)
        .padding(16)
        .frame(width: 280)
        .background(Color(hex: 0xF2F2F2))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Menu("Add Action") {
                ForEach(WorkflowAction.Kind.allCases, id: \.self) { kind in
                    Button(label(for: kind)) { appendAction(kind) }
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 120)
            TextField("Test query", text: model.bind(\.debugQuery))
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
            Button("Run") { model.runWorkflowDebug(workflowID) }
            Button("Step") { model.stepWorkflowDebug(workflowID) }
            Spacer()
            Button("Cancel") { model.cancelWorkflowEdit() }
            Button("Save") { model.saveWorkflowEdit() }.keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color(hex: 0x2A2A2A))
        .foregroundStyle(.white)
    }

    private var debuggerPane: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Debugger").font(.system(size: 11, weight: .semibold))
                Spacer()
                Button("Clear") { model.debugLines = [] }
                    .controlSize(.small)
                Button("Close") { model.debuggerVisible = false }
                    .controlSize(.small)
            }
            .foregroundStyle(.white.opacity(0.8))
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(model.debugLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(8)
        .frame(height: 150)
        .background(Color(hex: 0x111111))
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1) }
    }

    private func field(_ title: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(title, text: binding)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func symbol(for kind: WorkflowAction.Kind) -> String {
        switch kind {
        case .openURL: "globe"
        case .openApp: "app"
        case .shell: "terminal"
        case .copy: "doc.on.doc"
        case .largeType: "textformat.size"
        case .appleScript: "applescript"
        case .terminal: "terminal.fill"
        }
    }

    private func appendAction(_ kind: WorkflowAction.Kind = .copy) {
        guard let index = model.workflows.firstIndex(where: { $0.id == workflowID }) else { return }
        let value = kind == .openURL ? "https://www.google.com/search?q={query}" : (kind == .copy ? "{query}" : "")
        model.workflows[index].actions.append(WorkflowAction(kind: kind, value: value))
        model.workflowSelection = model.workflows[index].actions.count - 1
    }

    private func label(for kind: WorkflowAction.Kind) -> String {
        switch kind {
        case .openURL: "Open URL"
        case .openApp: "Open App"
        case .shell: "Run Script"
        case .copy: "Copy to Clipboard"
        case .largeType: "Large Type"
        case .appleScript: "Run AppleScript"
        case .terminal: "Open in Terminal"
        }
    }

    private func moveAction(_ index: Int, _ delta: Int) {
        guard let wf = model.workflows.firstIndex(where: { $0.id == workflowID }),
              model.workflows[wf].actions.indices.contains(index) else { return }
        let target = index + delta
        guard model.workflows[wf].actions.indices.contains(target) else { return }
        model.workflows[wf].actions.swapAt(index, target)
        model.workflowSelection = target
    }

    private func removeAction(_ index: Int) {
        guard let wf = model.workflows.firstIndex(where: { $0.id == workflowID }),
              model.workflows[wf].actions.indices.contains(index) else { return }
        model.workflows[wf].actions.remove(at: index)
        model.workflowSelection = model.workflows[wf].actions.isEmpty ? nil : min(index, model.workflows[wf].actions.count - 1)
    }
}


private struct WorkflowDropDelegate: DropDelegate {
    var model: AppModel
    var target: Int

    func dropEntered(info: DropInfo) {
        guard let source = model.workflowDragIndex, source != target else { return }
        model.moveWorkflowAction(from: source, to: target)
        model.workflowDragIndex = target
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        model.workflowDragIndex = nil
        return true
    }
}
