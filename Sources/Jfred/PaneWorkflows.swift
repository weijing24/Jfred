import SwiftUI
import JfredCore

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
        .background(Color(hex: 0x1E1E1E))
        .sheet(isPresented: Binding(
            get: { model.editingWorkflowID != nil },
            set: { presented in if !presented { model.cancelWorkflowEdit() } }
        )) {
            if let id = model.editingWorkflowID {
                WorkflowEditor(model: model, workflowID: id)
            }
        }
        .sheet(isPresented: model.bind(\.showTemplates)) { templateSheet }
        .sheet(isPresented: model.bind(\.showGallery)) { gallerySheet }
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
                                    Text("by \(workflow.author)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .foregroundStyle(.white)
                            .background(model.selectedWorkflow == workflow.id ? Color.white.opacity(0.12) : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 280)
        .background(Color(hex: 0x3A145C))
    }

    private var cards: some View {
        ScrollView {
            VStack(spacing: 12) {
                card("star.fill", "Jfred Gallery", "Browse the built-in workflows and turn them back on.") { model.showGallery = true }
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
                Image(systemName: symbol).font(.system(size: 26)).frame(width: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .semibold))
                    Text(text).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 78)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0x2A2A2A)))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Jfred Gallery") { model.showGallery = true }
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
        .background(Color(white: 0.93))
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

    private var gallerySheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Built-in gallery").font(.title3)
            ForEach(Seed.workflows()) { workflow in
                HStack {
                    VStack(alignment: .leading) {
                        Text(workflow.name)
                        Text(workflow.keyword).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.workflows.contains(where: { $0.builtin == workflow.builtin && workflow.builtin != nil }) {
                        Text("Installed").foregroundStyle(.secondary)
                    } else {
                        Button("Install") {
                            model.workflows.append(workflow)
                        }
                    }
                }
            }
            Button("Close") { model.showGallery = false }
        }
        .padding(20)
        .frame(width: 460)
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
            if workflow?.builtin != nil {
                Text("This is a built-in workflow. Its keyword still works, and the actions below are not used.")
                    .font(.caption).foregroundStyle(.secondary)
                if let summary = WorkflowMatching.summary(for: workflow?.builtin) {
                    Text(summary).font(.caption).foregroundStyle(.secondary)
                }
            }
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
