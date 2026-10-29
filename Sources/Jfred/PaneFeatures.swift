import AppKit
import SwiftUI
import JfredCore

struct FeaturesPane: View {
    var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            featureList
            VStack(spacing: 0) {
                PageHeaderBand(
                    icon: model.feature.symbol,
                    tint: tint(for: model.feature),
                    title: headerTitle,
                    subtitle: headerSubtitle
                )
                PageSurface {
                    FormPanel {
                        VStack(alignment: .leading, spacing: 16) {
                            switch model.feature {
                            case .defaultResults: defaultResults
                            case .fileSearch: fileSearch
                            case .universalActions: actions
                            case .webSearch: webSearch
                            case .bookmarks: bookmarks
                            case .clipboard: clipboard
                            case .snippets: snippets
                            case .calculator: calculator
                            case .dictionary: dictionary
                            case .onePassword: onePassword
                            case .system: system
                            case .terminal: terminal
                            case .largeType: largeType
                            case .previews: previews
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: model.bind(\.featureSheet)) { kind in
            sheetView(kind)
        }
        .sheet(isPresented: model.bind(\.showSnippetExpansionOptions)) {
            snippetExpansionSheet
        }
    }

    private var featureList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(FeatureID.allCases) { feature in
                    Button {
                        model.feature = feature
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: feature.symbol)
                                .font(.system(size: 17))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(tint(for: feature))
                                )
                            VStack(alignment: .leading, spacing: 1) {
                                Text(feature.title).font(.system(size: 13, weight: .semibold))
                                Text(feature.subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.82))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .frame(height: 42)
                        .foregroundStyle(.white)
                        .background(model.feature == feature ? Color.white.opacity(0.22) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)
        }
        .frame(width: 240)
        .jfredSidebar(tint: JfredColor.sidebarDeep)
        .layoutPriority(1)
    }

    func stringListEditor(title: String, hint: String, keyPath: WritableKeyPath<Preferences, [String]>) -> some View {
        SettingsLabeled(title: title) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsCard {
                    ScrollView {
                        VStack(spacing: 0) {
                            if model.preferences[keyPath: keyPath].isEmpty {
                                Text("None")
                                    .font(.system(size: 11))
                                    .foregroundStyle(JfredColor.sub)
                                    .frame(maxWidth: .infinity, minHeight: 60)
                            } else {
                                ForEach(Array(model.preferences[keyPath: keyPath].indices), id: \.self) { index in
                                    TextField(hint, text: model.bindElement(keyPath, index))
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 11, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .frame(height: 22)
                                    Divider().opacity(0.2)
                                }
                            }
                        }
                    }
                    .frame(width: 520, height: 110)
                }
                HStack(spacing: 6) {
                    Spacer()
                    Button("+") { model.preferences[keyPath: keyPath].append(hint) }
                    Button("−") {
                        if !model.preferences[keyPath: keyPath].isEmpty {
                            model.preferences[keyPath: keyPath].removeLast()
                        }
                    }
                }
                .frame(width: 520)
            }
        }
    }

    private func header(_ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: model.feature.symbol)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint(for: model.feature))
                )
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(JfredColor.ink)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(JfredColor.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
    }

    private var headerTitle: String {
        switch model.feature {
        case .defaultResults: "Default Results"
        case .fileSearch: "File Search"
        case .universalActions: "Universal Actions"
        case .webSearch: "Web Search"
        case .bookmarks: "Web Bookmarks"
        case .clipboard: "Clipboard History"
        case .snippets: "Snippets"
        case .calculator: "Calculator"
        case .dictionary: "Dictionary"
        case .onePassword: "1Password"
        case .system: "System"
        case .terminal: "Terminal"
        case .largeType: "Large Type"
        case .previews: "Previews"
        }
    }

    private var headerSubtitle: String {
        switch model.feature {
        case .defaultResults: "These are the main results Jfred presents by default, and where he looks for them."
        case .fileSearch: "Using the file search keywords is the best way to find files; it keeps the default results both fast and focused."
        case .universalActions: "Perform actions on selected items in macOS or Jfred's results."
        case .webSearch: "Search the web using the built-in default web searches or create your own custom web searches."
        case .bookmarks: "Search Safari and Google Chrome bookmarks."
        case .clipboard: "Automatically store copied items in a searchable clipboard history."
        case .snippets: "Keep your most useful snippets always at hand."
        case .calculator: "Do quick mathematical calculations and copy the result to the macOS clipboard."
        case .dictionary: "Look up words in Jfred or macOS's dictionary and paste them into another application."
        case .onePassword: "Search and open your 1Password 1Click Bookmarks."
        case .system: "Control macOS directly from your keyboard; ejecting, quitting and hiding apps."
        case .terminal: "Quickly open the terminal and run shell commands."
        case .largeType: "Show text and results in large characters across your screen."
        case .previews: "Customise usage of macOS Quick Look, and how Jfred displays file previews."
        }
    }

    private func tint(for feature: FeatureID) -> Color {
        switch feature {
        case .defaultResults: return Color(hex: 0x4F217A)
        case .fileSearch: return Color(hex: 0x2C6E9B)
        case .universalActions: return Color(hex: 0xB05A2A)
        case .webSearch: return Color(hex: 0x2E7D4F)
        case .bookmarks: return Color(hex: 0x3A74D8)
        case .clipboard: return Color(hex: 0xA06A3A)
        case .snippets: return Color(hex: 0x8E44AD)
        case .calculator: return Color(hex: 0x4A4A4A)
        case .dictionary: return Color(hex: 0xB03A2E)
        case .onePassword: return Color(hex: 0x2F4858)
        case .system: return Color(hex: 0x6A3D9A)
        case .terminal: return Color(hex: 0x2F2F2F)
        case .largeType: return Color(hex: 0x7A5C3E)
        case .previews: return Color(hex: 0x2F6F6F)
        }
    }

    func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).frame(width: 120, alignment: .trailing)
            content()
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private func sheetView(_ kind: FeatureSheet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch kind {
            case .appOptions:
                Text("Application options").font(.title3)
                Toggle("Include system applications", isOn: model.bindPref(\.includeSystemApps))
                Toggle("Include applications in your home folder", isOn: model.bindPref(\.includeUserApps))
                Toggle("Include preference panes", isOn: model.bindPref(\.includePreferencePanes))
            case .extras:
                Text("File types in default results").font(.title3)
                Text("These checkboxes also live on Default Results. Leave them off and use a leading space, open, or find when you want files.")
                    .foregroundStyle(.secondary)
            case .fallbacks:
                Text("Fallback searches").font(.title3)
                ForEach(Array(model.preferences.webSearches.enumerated()), id: \.element.id) { index, search in
                    Toggle("\(search.title) (\(search.keyword))", isOn: model.bindWeb(index, \.fallback))
                }
            }
            HStack {
                Spacer()
                Button("Done") { model.featureSheet = nil }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

enum FeatureSheet: String, Identifiable {
    case appOptions, extras, fallbacks
    var id: String { rawValue }
}
