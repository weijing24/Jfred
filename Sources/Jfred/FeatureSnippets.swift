import AppKit
import SwiftUI
import JfredCore

extension FeaturesPane {
    var snippets: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsLabeled(title: "Viewer Hotkey:") {
                        Text("⌥⌘S")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(JfredColor.hotkey)
                            .frame(width: 200, height: 26, alignment: .leading)
                            .padding(.horizontal, 8)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.12)))
                    }
                    SettingsLabeled(title: "Snippet Keyword:") {
                        Toggle("", isOn: model.bindPref(\.snippetsEnabled))
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                        TextField("snip", text: model.bindPref(\.snippetKeyword))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                        Toggle("Show Keyword in Result", isOn: model.bindPref(\.snippetShowKeywordInResult))
                            .toggleStyle(.checkbox)
                    }
                    SettingsNote("Use keyword to show snippets in Jfred's default results.")
                    SettingsLabeled(title: "Matching:") {
                        Picker("", selection: model.bindPref(\.snippetMatching)) {
                            Text("Name").tag("name")
                            Text("Keyword").tag("keyword")
                            Text("Name or Keyword").tag("nameandkeyword")
                        }
                        .labelsHidden()
                        .frame(width: 180)
                        Toggle("Word based", isOn: model.bindPref(\.snippetWordBased))
                            .toggleStyle(.checkbox)
                    }
                    SettingsNote("To match the behaviour of the Clipboard History search (non-anchored broad search), uncheck \"Word based\".")
                }
                .frame(maxWidth: 560, alignment: .leading)
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Automatically expand snippets by keyword", isOn: model.bindPref(\.snippetsEnabled))
                        .toggleStyle(.checkbox)
                    Text("Type a snippet keyword in any macOS text field and have it automatically replaced with your snippet. This requires Accessibility permission.")
                        .font(.system(size: 11))
                        .foregroundStyle(JfredColor.sub)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Auto Expansion Options") { model.showSnippetExpansionOptions = true }
                }
                .padding(14)
                .frame(width: 300, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color(hex: 0xF2F2F2)))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.07)))
            }
            HStack(alignment: .top, spacing: 10) {
                snippetCollectionsCard
                VStack(spacing: 8) {
                    HStack {
                        SettingsFilterField(placeholder: "Filter", text: model.bind(\.snippetSearch), width: 240)
                        Spacer()
                    }
                    SettingsCard {
                        VStack(spacing: 0) {
                            HStack(spacing: 8) {
                                Text("Name").frame(width: 150, alignment: .leading)
                                Text("Keyword").frame(width: 160, alignment: .leading)
                                Text("Snippet").frame(maxWidth: .infinity, alignment: .leading)
                                Text("Expand").frame(width: 50)
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(JfredColor.sub)
                            .padding(.horizontal, 6)
                            .frame(height: 26)
                            .background(Color(hex: 0xF4F4F4))
                            Divider()
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(visibleSnippets, id: \.snippet.id) { entry in
                                        snippetRow(index: entry.index, snippet: entry.snippet)
                                        Divider().opacity(0.25)
                                    }
                                }
                            }
                            .frame(height: 320)
                        }
                    }
                    HStack {
                        Button("Get Collections…") { model.section = .help }
                        Spacer()
                        Button("+") { addSnippet() }.frame(width: 26)
                        Button("−") { removeSnippet() }.frame(width: 26)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    var snippetExpansionSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Auto Expansion Options")
                .font(.system(size: 16, weight: .semibold))
            Toggle("Play sound when expanding", isOn: model.bindPref(\.snippetExpandPlaySound))
                .toggleStyle(.checkbox)
            Toggle("Restore clipboard after expanding", isOn: model.bindPref(\.snippetExpandRestoreClipboard))
                .toggleStyle(.checkbox)
            Text("Expansion replaces the typed keyword with the snippet. With clipboard restore disabled, the expanded snippet stays on the clipboard.")
                .font(.system(size: 11))
                .foregroundStyle(JfredColor.sub)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Done") { model.showSnippetExpansionOptions = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    var snippetCollections: [String] {
        Array(Set(model.snippets.map(\.collection).filter { !$0.isEmpty })).sorted()
    }

    var visibleSnippets: [(index: Int, snippet: Snippet)] {
        let q = model.snippetSearch.trimmingCharacters(in: .whitespaces)
        return model.snippets.enumerated().compactMap { index, snippet in
            if !model.snippetCollectionFilter.isEmpty, snippet.collection != model.snippetCollectionFilter { return nil }
            if !q.isEmpty {
                let hay = [snippet.name, snippet.keyword, snippet.text, snippet.collection].joined(separator: " ")
                if !hay.localizedCaseInsensitiveContains(q) { return nil }
            }
            return (index, snippet)
        }
    }

    var snippetCollectionsCard: some View {
        SettingsCard {
            ScrollView {
                VStack(spacing: 0) {
                    collectionRow("All Snippets", key: "", symbol: "square.stack.3d.up")
                    ForEach(snippetCollections, id: \.self) { name in
                        collectionRow(name, key: name, symbol: "folder")
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(width: 200, height: 372)
        }
    }

    func collectionRow(_ title: String, key: String, symbol: String) -> some View {
        Button {
            model.snippetCollectionFilter = key
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(JfredColor.sub)
                Text(title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer()
                Text("\(model.snippets.filter { key.isEmpty || $0.collection == key }.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(JfredColor.sub)
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(model.snippetCollectionFilter == key ? Color.accentColor.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func snippetRow(index: Int, snippet: Snippet) -> some View {
        HStack(spacing: 8) {
            TextField("Name", text: model.bindSnippet(index, \.name))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: 150)
            TextField("Keyword", text: model.bindSnippet(index, \.keyword))
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 160)
            TextField("Snippet", text: model.bindSnippet(index, \.text))
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
            Toggle("", isOn: model.bindSnippet(index, \.autoExpand))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 50)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .frame(height: 26)
        .background(model.selectedSnippetID == snippet.id ? Color.accentColor.opacity(0.10) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { model.selectedSnippetID = snippet.id }
    }

    func addSnippet() {
        let snippet = Snippet(name: "New snippet", keyword: ";new", text: "", autoExpand: true, collection: model.snippetCollectionFilter)
        model.snippets.append(snippet)
        model.selectedSnippetID = snippet.id
    }

    func removeSnippet() {
        guard let id = model.selectedSnippetID else { return }
        model.snippets.removeAll { $0.id == id }
        model.selectedSnippetID = nil
    }

}
