import AppKit
import SwiftUI
import JfredCore

extension FeaturesPane {
    var webSearch: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                SettingsTabBar(selection: model.bind(\.webSearchTab), tabs: ["Search", "URLs / History"])
                Spacer()
            }
            if model.webSearchTab == "Search" {
                SettingsPanel {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            SettingsFilterField(placeholder: "Filter", text: model.bind(\.webSearchFilter))
                            Spacer()
                            Toggle("Only show enabled searches", isOn: model.bind(\.webSearchOnlyEnabled))
                                .toggleStyle(.checkbox)
                                .font(.system(size: 12))
                        }
                        webSearchTable
                        HStack {
                            Spacer()
                            Button("Add Custom Search") { addWebSearch() }
                            Button("−") { removeSelectedWebSearch() }
                                .frame(width: 26)
                        }
                    }
                }
            } else {
                webSearchHistory
            }
        }
    }

    var visibleWebSearches: [(index: Int, search: WebSearch)] {
        let q = model.webSearchFilter.trimmingCharacters(in: .whitespaces)
        return model.preferences.webSearches.enumerated().compactMap { index, search in
            if model.webSearchOnlyEnabled, !search.enabled { return nil }
            if !q.isEmpty {
                let hay = [search.title, search.keyword, search.urlTemplate].joined(separator: " ")
                if !hay.localizedCaseInsensitiveContains(q) { return nil }
            }
            return (index, search)
        }
    }

    var webSearchTable: some View {
        SettingsCard {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("Keyword").frame(width: 140, alignment: .leading)
                    Text("Display text").frame(width: 200, alignment: .leading)
                    Text("URL").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Fallback").frame(width: 60)
                    Text("Enabled").frame(width: 60)
                }
                .font(.system(size: 11))
                .foregroundStyle(JfredColor.sub)
                .padding(.horizontal, 6)
                .frame(height: 26)
                .background(Color(hex: 0xF4F4F4))
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleWebSearches, id: \.search.id) { entry in
                            webSearchRow(index: entry.index, search: entry.search)
                            Divider().opacity(0.25)
                        }
                    }
                }
                .frame(height: 400)
            }
        }
    }

    func webSearchRow(index: Int, search: WebSearch) -> some View {
        HStack(spacing: 8) {
            TextField("Keyword", text: model.bindWeb(index, \.keyword))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: 140)
            TextField("Display text", text: model.bindWeb(index, \.title))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: 200)
            TextField("https://example.com/?q={query}", text: model.bindWeb(index, \.urlTemplate))
                .textFieldStyle(.plain)
                .font(.system(size: 10.5, design: .monospaced))
                .lineLimit(1)
            Toggle("", isOn: model.bindWeb(index, \.fallback))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 60)
            Toggle("", isOn: model.bindWeb(index, \.enabled))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 60)
        }
        .padding(.horizontal, 6)
        .frame(height: 26)
        .background(model.selectedWebSearchID == search.id ? Color.accentColor.opacity(0.10) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { model.selectedWebSearchID = search.id }
    }

    var webSearchHistory: some View {
        SettingsPanel {
            VStack(spacing: 10) {
                SettingsCard {
                    VStack(spacing: 0) {
                        if model.preferences.urlHistory.isEmpty {
                            Text("No URLs opened from the launcher yet.")
                                .font(.system(size: 12))
                                .foregroundStyle(JfredColor.sub)
                                .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(model.preferences.urlHistory, id: \.self) { url in
                                        HStack(spacing: 8) {
                                            Image(systemName: "globe")
                                                .font(.system(size: 12))
                                                .foregroundStyle(JfredColor.sub)
                                            Text(url)
                                                .font(.system(size: 12, design: .monospaced))
                                                .lineLimit(1)
                                            Spacer()
                                            Button("Open") {
                                                if let link = URL(string: url) { NSWorkspace.shared.open(link) }
                                            }
                                            .controlSize(.small)
                                        }
                                        .padding(.horizontal, 8)
                                        .frame(height: 26)
                                        Divider().opacity(0.25)
                                    }
                                }
                            }
                            .frame(height: 400)
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("Clear History") { model.preferences.urlHistory = [] }
                        .disabled(model.preferences.urlHistory.isEmpty)
                }
            }
        }
    }

    func addWebSearch() {
        let search = WebSearch(id: UUID().uuidString, title: "New Search", keyword: "kw", urlTemplate: "https://www.google.com/search?q={query}", enabled: true, fallback: false, symbol: "magnifyingglass")
        model.preferences.webSearches.append(search)
        model.selectedWebSearchID = search.id
    }

    func removeSelectedWebSearch() {
        guard let id = model.selectedWebSearchID else { return }
        model.preferences.webSearches.removeAll { $0.id == id }
        model.selectedWebSearchID = model.preferences.webSearches.last?.id
    }

}
