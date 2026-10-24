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
                cards
            }
            footer
        }
        .sheet(isPresented: Binding(
            get: { model.editingWorkflowID != nil },
            set: { presented in if !presented { model.cancelWorkflowEdit() } }
        )) {
            if let id = model.editingWorkflowID {
                WorkflowEditor(model: model, workflowID: id)
            }
        }
        .sheet(isPresented: model.bind(\.showTemplates)) { templateSheet }
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
                            model.selectedWorkflow = workflow.id
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
        .frame(width: 280)
        .jfredSidebar(tint: JfredColor.sidebarDeep)
    }

    @ViewBuilder
    private func workflowMenu(_ workflow: Workflow) -> some View {
        Toggle("Enabled", isOn: model.bindWorkflow(workflow.id, \.enabled))
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
        Button("Delete", role: .destructive) {
            model.workflows.removeAll { $0.id == workflow.id }
            if model.selectedWorkflow == workflow.id {
                model.selectedWorkflow = model.workflows.first?.id
            }
        }
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
                card("point.3.connected.trianglepath.dotted", "Create a new Workflow", "Jump in and create a blank Workflow.") { model.beginWorkflowEdit(blank()) }
                card("square.on.square", "Create a Workflow from a Template", "New to workflows? Try one of our Getting Started templates.") { model.showTemplates = true }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func card(_ symbol: String, _ title: String, _ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 26))
                    .frame(width: 54)
                    .foregroundStyle(JfredColor.hotkey)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(JfredColor.ink)
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(JfredColor.sub)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 78)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(JfredColor.line))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("+") { model.beginWorkflowEdit(blank()) }
            Button("−") {
                guard let id = model.selectedWorkflow else { return }
                model.workflows.removeAll { $0.id == id }
                model.selectedWorkflow = model.workflows.first?.id
            }
            Spacer()
            Text(model.debugLine).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color(white: 0.95))
        .overlay(alignment: .top) {
            Rectangle().fill(JfredColor.line).frame(height: 1)
        }
        .foregroundStyle(.black)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workflow").font(.title3)
            TextField("Name", text: model.bindWorkflow(workflowID, \.name))
            TextField("Keyword", text: model.bindWorkflow(workflowID, \.keyword))
            TextField("Author", text: model.bindWorkflow(workflowID, \.author))
            TextField("SF Symbol", text: model.bindWorkflow(workflowID, \.symbol))
            Toggle("Enabled", isOn: model.bindWorkflow(workflowID, \.enabled))
            ForEach(Array((workflow?.actions ?? []).enumerated()), id: \.element.id) { index, _ in
                HStack {
                    Picker("Action", selection: model.bindAction(workflowID, index, \.kind)) {
                        ForEach(WorkflowAction.Kind.allCases, id: \.self) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .frame(width: 150)
                    TextField("Value, {query} is the text after the keyword", text: model.bindAction(workflowID, index, \.value))
                }
            }
            HStack {
                Button("Add action") { appendAction() }
                Button("Remove action") { removeAction() }
            }
            HStack {
                Spacer()
                Button("Cancel") { model.cancelWorkflowEdit() }
                Button("Save") { model.saveWorkflowEdit() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    private func appendAction() {
        guard let index = model.workflows.firstIndex(where: { $0.id == workflowID }) else { return }
        model.workflows[index].actions.append(WorkflowAction(kind: .shell, value: ""))
    }

    private func removeAction() {
        guard let index = model.workflows.firstIndex(where: { $0.id == workflowID }) else { return }
        if !model.workflows[index].actions.isEmpty {
            model.workflows[index].actions.removeLast()
        }
    }
}
