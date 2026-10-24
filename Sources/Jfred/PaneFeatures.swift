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
                            case .contacts: contactsPage
                            case .music: musicPage
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

    private var defaultResults: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeled("Applications:") { Button("Options...") { model.featureSheet = .appOptions } }
            labeled("Essentials:") {
                Toggle("Contacts", isOn: model.bindPref(\.contactsEnabled))
                Toggle("System Settings", isOn: model.bindPref(\.systemSettingsEnabled))
            }
            labeled("Extras:") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 22) {
                        Toggle("Folders", isOn: model.bindPref(\.extraFolders))
                        Toggle("Documents", isOn: model.bindPref(\.extraDocuments))
                        Toggle("Text Files", isOn: model.bindPref(\.extraText))
                    }
                    HStack(spacing: 22) {
                        Toggle("Images", isOn: model.bindPref(\.extraImages))
                        Toggle("Archives", isOn: model.bindPref(\.extraArchives))
                        Toggle("AppleScripts", isOn: model.bindPref(\.extraScripts))
                        Spacer()
                        Button("Advanced...") { model.featureSheet = .extras }
                    }
                }
            }
            Text("Note: Jfred works most efficiently if you only have 'Essential' items ticked and use the 'open' keyword to find files. You can also press space immediately after activating Jfred to quickly enter the file search mode.")
                .font(.system(size: 11)).foregroundStyle(JfredColor.sub).padding(.leading, 132)
            labeled("Unintelligent:") { Toggle("Search all file types", isOn: model.bindPref(\.searchAllFileTypes)) }
            Text("WARNING: Selecting this will slow down and muddle the default search results considerably. Use 'open' and 'find' for file operations instead.")
                .font(.system(size: 11)).foregroundStyle(JfredColor.sub).padding(.leading, 132)
            labeled("Search Scope:") {
                HStack(spacing: 16) {
                    Toggle("macOS Applications folder", isOn: model.bindPref(\.scopeApplications))
                    Toggle("Folders in Home - Excluding ~/Library", isOn: model.bindPref(\.scopeHome))
                }
            }
            scopeList
            labeled("Fallbacks:") {
                HStack {
                    Picker("", selection: model.bindPref(\.fallbackMode)) {
                        Text("Only show fallbacks when there are no results").tag("none")
                        Text("Always show fallbacks").tag("always")
                        Text("Never show fallbacks").tag("never")
                    }
                    .labelsHidden()
                    .frame(width: 360)
                    Button("Setup fallback results") { model.featureSheet = .fallbacks }
                }
            }
            Text("Fallbacks are shown when Jfred is unable to find any results. If the option to intelligently show fallbacks is selected, Jfred will show the fallbacks when relevant. By default, Jfred shows Google, Amazon and Wikipedia.")
                .font(.system(size: 11)).foregroundStyle(JfredColor.sub).padding(.leading, 132)
        }
    }

    private var scopeList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.preferences.scopePaths, id: \.self) { path in
                        Button {
                            model.selectedScopePath = path
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.square.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.accentColor)
                                Text(path)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(JfredColor.ink)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(
                                model.selectedScopePath == path
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear
                            )
                        }
                        .buttonStyle(.plain)
                        Divider().opacity(0.3)
                    }
                }
                .padding(4)
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
            )
            .frame(height: 280)

            HStack(alignment: .top, spacing: 12) {
                Text("These folders define where Jfred looks for files, applications and metadata. Fewer paths give more accurate results. Drop folders above from Finder or Jfred.")
                    .font(.system(size: 11))
                    .foregroundStyle(JfredColor.sub)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                HStack(spacing: 6) {
                    Button("+") { model.addScopeFolder() }
                    Button("−") {
                        if let selectedScopePath = model.selectedScopePath {
                            model.preferences.scopePaths.removeAll { $0 == selectedScopePath }
                        }
                    }
                    Button("Reset...") { model.preferences.scopePaths = Preferences.defaultScope }
                }
                .fixedSize()
            }
        }
        .padding(.leading, 132)
    }

    private var fileSearch: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                SettingsTabBar(selection: model.bind(\.fileSearchTab), tabs: ["Search", "Navigation", "Buffer", "Advanced"])
                Spacer()
            }
            switch model.fileSearchTab {
            case "Navigation": fileSearchNavigationTab
            case "Buffer": fileSearchBufferTab
            case "Advanced": fileSearchAdvancedTab
            default: fileSearchSearchTab
            }
        }
    }

    private var fileSearchSearchTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Quick Search:") {
                Toggle("Enable Quick File Search mode", isOn: model.bindPref(\.quickSearchEnabled))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Search for and open files very quickly by prefixing your search term with a space (or '). This is the best way to find files.")
            HStack(alignment: .top, spacing: 24) {
                keywordBlock("Opening Files:", "Use the keyword followed by the search term, e.g. 'open magictricks.pdf' to open the specified file.", keyword: model.bindPref(\.fileOpenKeyword), enabled: model.bindPref(\.fileOpenEnabled))
                keywordBlock("Revealing Files:", "Use the keyword followed by the search term, e.g. 'find magictricks.pdf' to reveal the file in Finder.", keyword: model.bindPref(\.fileFindKeyword), enabled: model.bindPref(\.fileFindEnabled))
            }
            HStack(alignment: .top, spacing: 24) {
                keywordBlock("Inside Files:", "Use the keyword followed by the search term, e.g. 'in rabbit from hat' to look for the contents of a file.", keyword: model.bindPref(\.fileInsideKeyword), enabled: model.bindPref(\.fileInsideEnabled))
                keywordBlock("File Tags:", "Use the keyword followed by the tags, e.g. 'tags magic tricks' to look for files tagged with all matching terms.", keyword: model.bindPref(\.fileTagsKeyword), enabled: model.bindPref(\.fileTagsEnabled))
            }
            SettingsLabeled(title: "Don't Show:") {
                LazyVGrid(
                    columns: [GridItem(.fixed(110), alignment: .leading), GridItem(.fixed(110), alignment: .leading), GridItem(.fixed(110), alignment: .leading)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(hiddenTypeNames, id: \.self) { name in
                        Toggle(name, isOn: model.bindMember(\.hiddenFileTypes, name))
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12))
                    }
                }
            }
            SettingsNote("Use these to filter out files you are not interested in when using the open, reveal and inside keywords.")
            SettingsLabeled(title: "Result Limit:") {
                Picker("", selection: model.bindPref(\.fileSearchMax)) {
                    ForEach([15, 20, 30, 40, 50], id: \.self) { Text("\($0)").tag($0) }
                }
                .labelsHidden()
                .frame(width: 110)
            }
            SettingsNote("Select more results for more flexibility or fewer results for higher performance.")
        }
    }

    private var fileSearchNavigationTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Previous Path:") {
                Text("Use this hotkey or keyword to show the file browser for the last browsed path from the results.")
                    .font(.system(size: 12))
                    .foregroundStyle(JfredColor.sub)
                    .frame(maxWidth: 480, alignment: .leading)
            }
            SettingsLabeled(title: "Folder Keys:") {
                Toggle("Use ← and → for folder navigation", isOn: model.bindPref(\.fileNavigateWithArrows))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("By default, → shows the action panel and you can use ⌘↓ and ⌘↑ to navigate in and out of folders.")
            SettingsLabeled(title: "Return:") {
                Toggle("Use ↩ to open folders in Finder", isOn: model.bindPref(\.fileOpenFoldersInFinder))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("By default, while browsing ↩ navigates into a folder. At any point you can use ⌘O to open a folder in Finder.")
            SettingsLabeled(title: "Open Files:") {
                Toggle("Reveal files in Finder instead of opening them", isOn: model.bindPref(\.fileOpenWithFinder))
                    .toggleStyle(.checkbox)
            }
        }
    }

    private var fileSearchBufferTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Buffer:") {
                Toggle("Enable temporary file buffer", isOn: model.bindPref(\.fileBufferEnabled))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("The buffer is controlled using the ⌥ key in combination with the selected file in the results: ⌥↑ adds/removes, ⌥↓ adds and moves down, ⌥← removes the last item, ⌥→ actions all items.")
            SettingsLabeled(title: "Clearing:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Clear after actioning items in the buffer", isOn: model.bindPref(\.fileClearBufferAfterAction))
                        .toggleStyle(.checkbox)
                    Stepper("Clear if buffer isn't used for \(model.preferences.fileBufferTimeoutMinutes) minutes", value: model.bindPref(\.fileBufferTimeoutMinutes), in: 1...60)
                }
            }
            SettingsLabeled(title: "Keys:") {
                Toggle("Use ⇧⌥ as modifier key", isOn: model.bindPref(\.fileUseShiftOptionBuffer))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Use the same keys as above but with ⇧⌥ as the modifier instead of ⌥, which may better fit your default key bindings.")
        }
    }

    private var fileSearchAdvancedTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Home Folder:") {
                TextField("~ (Unix standard)", text: model.bindPref(\.fileCustomHomeFolder))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
            }
            SettingsNote("Use a custom home folder location. The default ~ follows the Unix standard.")
            SettingsLabeled(title: "Copy Path:") {
                Toggle("Escape path on 'Copy path to Clipboard' action", isOn: model.bindPref(\.fileEscapePathForTerminal))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Escape the path for Terminal, e.g. '/Users/name/Desktop/Andrew\'s Folder!'.")
            SettingsLabeled(title: "AppleScripts:") {
                Toggle("Run AppleScripts instead of opening", isOn: model.bindPref(\.fileRunAppleScriptsInsteadOfOpening))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("When dealing with AppleScripts in results and file navigation, run them on pressing return instead of opening. Use ⌘O to open them at any point.")
            SettingsLabeled(title: "Performance:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Use file type icons for files on external drives", isOn: model.bindPref(\.fileUseTypeIconsForExternal))
                        .toggleStyle(.checkbox)
                    Toggle("Touch folders after opening them", isOn: model.bindPref(\.fileTouchFolders))
                        .toggleStyle(.checkbox)
                    Toggle("Touch aliases after opening them", isOn: model.bindPref(\.fileTouchAliases))
                        .toggleStyle(.checkbox)
                }
            }
            SettingsNote("Touching a folder updates kMDItemFSContentChangeDate so it is prioritised in Spotlight and file search results.")
        }
    }

    private var hiddenTypeNames: [String] {
        ["Emails", "Contacts", "Calendar", "Bookmarks", "History", "Messages", "Images", "Music", "Plist files", "Source files"]
    }

    private func keywordBlock(_ title: String, _ note: String, keyword: Binding<String>, enabled: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13))
                    .frame(width: 100, alignment: .trailing)
                Toggle("", isOn: enabled)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                TextField("keyword", text: keyword)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
            }
            Text(note)
                .font(.system(size: 11))
                .foregroundStyle(JfredColor.sub)
                .frame(width: 260, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 120)
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                SettingsTabBar(selection: model.bind(\.actionsTab), tabs: ["General", "Actions"])
                Spacer()
            }
            if model.actionsTab == "Actions" {
                SettingsCard {
                    VStack(spacing: 0) {
                        actionRow("Copy", "⌘C", "Copy the path, URL, or subtitle")
                        Divider().opacity(0.25)
                        actionRow("Large Type", "⌘L", "Show the selected item in large type")
                        Divider().opacity(0.25)
                        actionRow("Quick Look", "⌘Y", "Preview the selected file with Quick Look")
                        Divider().opacity(0.25)
                        actionRow("Complete", "⇥", "Insert the selected title into the query")
                        Divider().opacity(0.25)
                        actionRow("Actions", "→ / ⌘K", "Show the action panel for the selected result")
                        Divider().opacity(0.25)
                        actionRow("Reveal", "⌘O", "Reveal the selected file in Finder")
                    }
                }
                .frame(maxWidth: 620)
                SettingsNote("Actions are generated per result type: apps/files, URLs, contacts, clipboard items and calculations.")
            } else {
                SettingsLabeled(title: "Show Actions:") {
                    HStack(spacing: 12) {
                        Toggle("→", isOn: model.bindPref(\.uaShowRightArrow))
                            .toggleStyle(.checkbox)
                        Toggle("fn", isOn: model.bindPref(\.uaShowFunction))
                            .toggleStyle(.checkbox)
                        Toggle("ctrl", isOn: model.bindPref(\.uaShowControl))
                            .toggleStyle(.checkbox)
                        Toggle("⌘", isOn: model.bindPref(\.uaShowCommand))
                            .toggleStyle(.checkbox)
                        Text("to action selected item")
                            .font(.system(size: 12))
                            .foregroundStyle(JfredColor.sub)
                    }
                }
                SettingsNote("Use these options to tweak how else you can show the action panel. If → is selected, use ⇧→ in views which use → for navigation.")
                SettingsLabeled(title: "Selection Hotkey:") {
                    TextField("⌥⌘\\", text: model.bindPref(\.uaSelectionHotkey))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }
                SettingsNote("Use this hotkey to show the actions panel for the currently selected item in macOS.")
                SettingsLabeled(title: "Action Ordering:") {
                    Toggle("Sort actions by last used per type", isOn: model.bindPref(\.uaSortByUsage))
                        .toggleStyle(.checkbox)
                }
                SettingsNote("By default, Jfred fixes the order of actions. If you prefer, Jfred will order actions based on your usage per type actioned.")
            }
        }
    }

    private func actionRow(_ title: String, _ shortcut: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 110, alignment: .leading)
            Text(shortcut)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(JfredColor.sub)
                .frame(width: 60, alignment: .leading)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(JfredColor.sub)
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
    }

    private func modifierPicker(_ title: String, selection: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12))
                .frame(width: 80, alignment: .trailing)
            Picker("", selection: selection) {
                Text("Search with default web search").tag("web")
                Text("Search with Finder").tag("finder")
                Text("Reveal in Finder (if local)").tag("reveal")
                Text("Primary action").tag("primary")
            }
            .labelsHidden()
            .frame(width: 280)
        }
    }

    private var webSearch: some View {
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

    private var visibleWebSearches: [(index: Int, search: WebSearch)] {
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

    private var webSearchTable: some View {
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

    private func webSearchRow(index: Int, search: WebSearch) -> some View {
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

    private var webSearchHistory: some View {
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

    private func addWebSearch() {
        let search = WebSearch(id: UUID().uuidString, title: "New Search", keyword: "kw", urlTemplate: "https://www.google.com/search?q={query}", enabled: true, fallback: false, symbol: "magnifyingglass")
        model.preferences.webSearches.append(search)
        model.selectedWebSearchID = search.id
    }

    private func removeSelectedWebSearch() {
        guard let id = model.selectedWebSearchID else { return }
        model.preferences.webSearches.removeAll { $0.id == id }
        model.selectedWebSearchID = model.preferences.webSearches.last?.id
    }

    private var bookmarks: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Sources:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Safari Bookmarks", isOn: model.bindPref(\.safariBookmarks))
                        .toggleStyle(.checkbox)
                    Toggle("Google Chrome Bookmarks", isOn: model.bindPref(\.chromeBookmarks))
                        .toggleStyle(.checkbox)
                }
            }
            SettingsNote("Jfred maintains an index of the selected bookmark sources. Deselect items if they aren't required, as this will help Jfred stay light weight.")
            SettingsLabeled(title: "Show Bookmarks:") {
                Picker("", selection: model.bindPref(\.bookmarkResultMode)) {
                    Text("in default results").tag("default")
                    Text("with keyword").tag("keyword")
                }
                .labelsHidden()
                .frame(width: 180)
                if model.preferences.bookmarkResultMode == "keyword" {
                    TextField("keyword", text: model.bindPref(\.bookmarkKeyword))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
            }
            SettingsNote("Where to show the bookmarks. Use a keyword to keep Jfred's default results free from noise.")
            SettingsLabeled(title: "Open Bookmarks:") {
                Picker("", selection: model.bindPref(\.bookmarkOpenMode)) {
                    Text("in macOS default browser").tag("macos")
                    Text("in the bookmark's source browser").tag("source")
                }
                .labelsHidden()
                .frame(width: 280)
            }
            SettingsNote("Select to open all bookmarks in your macOS default web browser, or in the bookmark's respective source browser.")
            SettingsLabeled(title: "Index:") {
                Text("\(model.links.count) bookmarks indexed")
                    .font(.system(size: 12))
                    .foregroundStyle(JfredColor.sub)
                Button("Reload bookmarks") { model.reloadLinks() }
            }
        }
    }

    private var clipboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                SettingsTabBar(selection: model.bind(\.clipboardTab), tabs: ["History", "Merging", "Advanced"])
                Spacer()
            }
            switch model.clipboardTab {
            case "Merging": clipboardMergingTab
            case "Advanced": clipboardAdvancedTab
            default: clipboardHistoryTab
            }
        }
    }

    private var clipboardHistoryTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Clipboard History:") {
                HStack(alignment: .top, spacing: 12) {
                    clipKeepBox("Keep Plain Text", isOn: model.bindPref(\.clipboardKeepText), enabled: true)
                    clipKeepBox("Keep Images", isOn: model.bindPref(\.clipboardKeepImages), enabled: true)
                    clipKeepBox("Keep File Lists", isOn: model.bindPref(\.clipboardKeepFiles), enabled: true)
                }
            }
            SettingsNote("When disabled, the clipboard viewer can still show your snippets.")
            SettingsLabeled(title: "Viewer Hotkey:") {
                HStack(spacing: 8) {
                    Text("⌥⌘C")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(JfredColor.hotkey)
                        .frame(width: 180, height: 26, alignment: .leading)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.12)))
                    Text("Hotkey is not configurable yet")
                        .font(.system(size: 11))
                        .foregroundStyle(JfredColor.sub)
                }
            }
            SettingsLabeled(title: "Viewer Keyword:") {
                Toggle("", isOn: model.bindPref(\.clipboardEnabled))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                TextField("clipboard", text: model.bindPref(\.clipboardViewerKeyword))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 182)
            }
            SettingsNote("Hotkey and keyword to open Jfred's clipboard viewer.")
            SettingsLabeled(title: "Clear Keyword:") {
                TextField("clear", text: model.bindPref(\.clipboardClearKeyword))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 182)
                Button("Clear All History Now") { model.clearClipboardHistory() }
            }
            SettingsNote("Clear the Clipboard History. This keyword allows for clearing all history or just history for the past 5 or 15 minutes.")
            SettingsLabeled(title: "Snippets:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Show \"All Snippets\" at top of Clipboard History", isOn: model.bindPref(\.clipboardSnippetsAtTop))
                        .toggleStyle(.checkbox)
                    Toggle("Show Snippets when searching Clipboard History", isOn: model.bindPref(\.clipboardSnippetsWhenSearching))
                        .toggleStyle(.checkbox)
                }
            }
            SettingsNote("Integrate your snippets in the clipboard history viewer.")
            SettingsLabeled(title: "Universal:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Ignore Text and Images from other Apple devices", isOn: model.bindPref(\.clipboardIgnoreUniversalText))
                        .toggleStyle(.checkbox)
                    Toggle("Ignore File Lists from other Apple devices", isOn: model.bindPref(\.clipboardIgnoreUniversalFiles))
                        .toggleStyle(.checkbox)
                }
            }
            SettingsNote("These options control whether Jfred ignores the macOS Universal Clipboard.\nNote: File lists are not fully compatible with clipboard history, so are disabled by default.")
        }
    }

    private var clipboardMergingTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Merging:") {
                Toggle("Fast append selected text", isOn: model.bindPref(\.clipboardFastAppend))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Hold ⌘ and double tap C to append the currently selected clipboard item to the previously copied text in the Clipboard History.")
            SettingsLabeled(title: "") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Separate appended item with").font(.system(size: 12))
                        Picker("", selection: model.bindPref(\.clipboardFastAppendSeparator)) {
                            Text("space").tag("space")
                            Text("new line").tag("newline")
                            Text("nothing").tag("none")
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    Toggle("Play a sound when appending", isOn: model.bindPref(\.clipboardFastAppendPlaySound))
                        .toggleStyle(.checkbox)
                    Toggle("Place merged text back into macOS clipboard", isOn: model.bindPref(\.clipboardFastAppendBackToClipboard))
                        .toggleStyle(.checkbox)
                }
            }
            SettingsNote("By placing the merged text back into the macOS clipboard, you can paste with ⌘V without having to use Jfred's Clipboard History view.")
            Divider()
            SettingsLabeled(title: "Pasting:") {
                Toggle("Auto-paste on return", isOn: model.bindPref(\.clipboardAutoPaste))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Automatically paste selected item to the currently active application.")
            SettingsLabeled(title: "Duplicates:") {
                Toggle("Ignore consecutive duplicate clips", isOn: model.bindPref(\.clipboardIgnoreDuplicates))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("When disabled, copying the same text twice in a row creates two history entries.")
            SettingsLabeled(title: "Clean Up:") {
                Button("Remove Duplicates Now") { removeDuplicateClips() }
            }
            SettingsNote("Removes older copies of identical clips, keeping the most recent one.")
        }
    }

    private var clipboardAdvancedTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Max Clip Size:") {
                Stepper(value: model.bindPref(\.clipboardMaxSize), in: 4096...2_000_000, step: 16384) {
                    Text("\(model.preferences.clipboardMaxSize / 1024)k characters")
                        .font(.system(size: 12))
                }
                .frame(width: 200)
            }
            SettingsNote("Ignore any copied text over the specified limit. This prevents accidental Clipboard History bloating.")
            SettingsLabeled(title: "Privacy:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Ignore clipboard data marked as Concealed", isOn: model.bindPref(\.clipboardIgnoreConcealed))
                        .toggleStyle(.checkbox)
                    Toggle("Ignore clipboard data marked as Auto Generated", isOn: model.bindPref(\.clipboardIgnoreAutoGenerated))
                        .toggleStyle(.checkbox)
                }
            }
            SettingsNote("Apps can mark data as org.nspasteboard.ConcealedType if it is potentially sensitive, or org.nspasteboard.AutoGeneratedType if it has been automatically placed in the clipboard without user intent.")
            SettingsLabeled(title: "Matching:") {
                Toggle("Diacritic and Unicode case insensitive matching of clipboard history", isOn: model.bindPref(\.clipboardUnicodeMatching))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Note that with very large clipboard databases, this can have a small effect on performance as Jfred implements a matching function for this.")
            SettingsLabeled(title: "Behaviour:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Move items to top of clipboard history when used", isOn: model.bindPref(\.clipboardMoveToTopOnUse))
                        .toggleStyle(.checkbox)
                    Toggle("Convert image data to PNG on pasting", isOn: model.bindPref(\.clipboardConvertImagesToPNG))
                        .toggleStyle(.checkbox)
                    Toggle("Clear clipboard history when Jfred quits", isOn: model.bindPref(\.clipboardClearOnQuit))
                        .toggleStyle(.checkbox)
                }
            }
            SettingsNote("The clipboard history is stored locally with 0600 permissions inside Jfred's support folder. Items copied from 1Password, Keychain Access, Passwords, Wallet and SecurityAgent are never stored. Enable clearing on quit if you don't want it to persist.")
        }
    }

    private func removeDuplicateClips() {
        var seen = Set<String>()
        model.clips.removeAll { clip in
            !seen.insert(clip.text).inserted
        }
    }

    private func clipKeepBox(_ title: String, isOn: Binding<Bool>, enabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: isOn)
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
                .disabled(!enabled)
            Picker("", selection: model.bindPref(\.clipboardRetention)) {
                ForEach(["1 day", "1 week", "1 month", "3 months", "1 year", "never"], id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 132)
            .disabled(!enabled)
        }
        .padding(10)
        .frame(width: 186, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(hex: 0xE2E2E2)))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.black.opacity(0.08)))
    }

    private var snippets: some View {
        VStack(alignment: .leading, spacing: 14) {
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
            SettingsNote("Use the keyword to show snippets in the default results.")
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
            SettingsLabeled(title: "Auto Expansion:") {
                Toggle("Automatically expand snippets by keyword", isOn: model.bindPref(\.snippetsEnabled))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Type a snippet keyword in any text field and have it replaced with your snippet. This requires Accessibility permission.")
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
                        Spacer()
                        Button("+") { addSnippet() }.frame(width: 26)
                        Button("−") { removeSnippet() }.frame(width: 26)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var snippetCollections: [String] {
        Array(Set(model.snippets.map(\.collection).filter { !$0.isEmpty })).sorted()
    }

    private var visibleSnippets: [(index: Int, snippet: Snippet)] {
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

    private var snippetCollectionsCard: some View {
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

    private func collectionRow(_ title: String, key: String, symbol: String) -> some View {
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

    private func snippetRow(index: Int, snippet: Snippet) -> some View {
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

    private func addSnippet() {
        let snippet = Snippet(name: "New snippet", keyword: ";new", text: "", autoExpand: true, collection: model.snippetCollectionFilter)
        model.snippets.append(snippet)
        model.selectedSnippetID = snippet.id
    }

    private func removeSnippet() {
        guard let id = model.selectedSnippetID else { return }
        model.snippets.removeAll { $0.id == id }
        model.selectedSnippetID = nil
    }

    private var contactsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                SettingsTabBar(selection: model.bind(\.contactsTab), tabs: ["Contacts", "Email", "Advanced"])
                Spacer()
            }
            switch model.contactsTab {
            case "Email": contactsEmailTab
            case "Advanced": contactsAdvancedTab
            default: contactsGeneralTab
            }
        }
    }

    private var contactsGeneralTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Contacts:") {
                Toggle("Open Contacts in Jfred", isOn: model.bindPref(\.contactsOpenInAlfred))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Instead of opening in Apple's Contacts.app. If you enable this feature, you can still open contacts in Contacts.app from the action panel.")
            SettingsLabeled(title: "Display:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Show title", isOn: model.bindPref(\.contactsShowTitle))
                        .toggleStyle(.checkbox)
                    Toggle("Show job title", isOn: model.bindPref(\.contactsShowJobTitle))
                        .toggleStyle(.checkbox)
                    Toggle("Invert name order", isOn: model.bindPref(\.contactsInvertName))
                        .toggleStyle(.checkbox)
                }
            }
            SettingsLabeled(title: "Maps:") {
                TextField("https://maps.apple.com/?q={query}", text: model.bindPref(\.contactsMapURL))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 360)
            }
            SettingsNote("The URL used by the Show in Maps action. {query} is replaced with the contact's address or name.")
            SettingsLabeled(title: "Status:") {
                Text(model.contacts.isEmpty ? "No contacts loaded. Grant Contacts access, then reload." : "\(model.contacts.count) contacts indexed")
                    .font(.system(size: 12))
                    .foregroundStyle(JfredColor.sub)
                Button("Grant Access…") { model.requestContactsAccess() }
                Button("Reload") { model.reloadContacts() }
            }
            SettingsNote("Jfred reads contact names, email addresses, phone numbers and job titles. The data stays on this Mac and is only used for launcher results.")
        }
    }

    private var contactsEmailTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Email:") {
                Text("Email actions open the macOS default mail application. Use the action panel on a contact result to start a new message.")
                    .font(.system(size: 12))
                    .foregroundStyle(JfredColor.sub)
                    .frame(maxWidth: 520, alignment: .leading)
            }
            SettingsLabeled(title: "Gmail:") {
                Text("https://mail.google.com/mail/?view=cm&fs=1&to={query}")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(JfredColor.sub)
                    .textSelection(.enabled)
            }
            SettingsNote("A {query} placeholder is replaced with the contact's email address when a custom email URL is used.")
        }
    }

    private var contactsAdvancedTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Maps:") {
                TextField("https://maps.apple.com/?q={query}", text: model.bindPref(\.contactsMapURL))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 420)
            }
            SettingsNote("The URL used by the Show in Maps action. {query} is replaced with the contact's address or name.")
            SettingsLabeled(title: "Opening:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Use a custom URL handler", isOn: model.bindPref(\.contactsURLHandlerEnabled))
                        .toggleStyle(.checkbox)
                    TextField("addressbook://{uid}", text: model.bindPref(\.contactsURLHandler))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 420)
                }
            }
            SettingsNote("When enabled, opening a contact uses this URL with {uid} replaced by the contact identifier.")
            SettingsLabeled(title: "Permissions:") {
                Button("Grant Contacts Access…") { model.requestContactsAccess() }
                Button("Reload") { model.reloadContacts() }
            }
            SettingsNote("Jfred only requests Contacts access when you press Grant Access. Without it, contact results are simply absent.")
        }
    }

    private var musicPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                SettingsTabBar(selection: model.bind(\.musicTab), tabs: ["General", "Keywords", "Advanced"])
                Spacer()
            }
            switch model.musicTab {
            case "Keywords": musicKeywordsTab
            case "Advanced": musicAdvancedTab
            default: musicGeneralTab
            }
        }
    }

    private var musicGeneralTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Mini Player:") {
                Toggle("Enable Music mini player", isOn: model.bindPref(\.musicEnabled))
                    .toggleStyle(.checkbox)
                TextField("music", text: model.bindPref(\.musicKeyword))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
            }
            SettingsNote("Use this hotkey or keyword to show the Music Mini Player. The keyword opens Music playback commands in the launcher.")
            SettingsLabeled(title: "Playback:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Hide Mini Player after selecting song", isOn: model.bindPref(\.musicHideMiniPlayerAfterSong))
                        .toggleStyle(.checkbox)
                    Toggle("When randomising, only play larger albums", isOn: model.bindPref(\.musicRandomLargerAlbums))
                        .toggleStyle(.checkbox)
                    Toggle("Include Playlists in Mini Player Search Results", isOn: model.bindPref(\.musicIncludePlaylists))
                        .toggleStyle(.checkbox)
                }
            }
            SettingsLabeled(title: "Now Playing:") {
                Text(model.musicTrack.isEmpty ? "Nothing playing" : model.musicTrack)
                    .font(.system(size: 12))
                    .foregroundStyle(JfredColor.sub)
                    .lineLimit(1)
                Button("Refresh") { model.refreshMusicTrack() }
            }
            SettingsLabeled(title: "Controls:") {
                HStack(spacing: 8) {
                    Button("Play / Pause") { _ = MusicService.playPause() }
                    Button("Previous") { _ = MusicService.previous() }
                    Button("Next") { _ = MusicService.next() }
                }
            }
            SettingsNote("Music control uses AppleScript and requires Automation access to Music.app. Jfred never reads or uploads your music library.")
        }
    }

    private var musicKeywordsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Mini Player Keyword:") {
                Toggle("", isOn: model.bindPref(\.musicEnabled))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                TextField("music", text: model.bindPref(\.musicKeyword))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 182)
            }
            SettingsNote("Use this hotkey or keyword to show the Music Mini Player.")
            SettingsLabeled(title: "Play Keyword:") {
                Text("play")
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 120, alignment: .leading)
                Text("play <song> starts the first matching song or album.")
                    .font(.system(size: 12))
                    .foregroundStyle(JfredColor.sub)
            }
            SettingsNote("The play keyword is always available while Music is enabled.")
        }
    }

    private var musicAdvancedTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Playback:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Hide Mini Player after selecting song", isOn: model.bindPref(\.musicHideMiniPlayerAfterSong))
                        .toggleStyle(.checkbox)
                    Toggle("When randomising, only play larger albums", isOn: model.bindPref(\.musicRandomLargerAlbums))
                        .toggleStyle(.checkbox)
                    Toggle("Include Playlists in Mini Player Search Results", isOn: model.bindPref(\.musicIncludePlaylists))
                        .toggleStyle(.checkbox)
                }
            }
            SettingsNote("Jfred never reads or uploads your music library. Playback is controlled through AppleScript.")
        }
    }

    private var calculator: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Calculator:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Enable standard calculator", isOn: model.bindPref(\.calculatorEnabled))
                        .toggleStyle(.checkbox)
                    Toggle("Enable advanced calculator with keyword '='", isOn: model.bindPref(\.calculatorAdvanced))
                        .toggleStyle(.checkbox)
                }
            }
            SettingsNote("= before your calculation enables advanced mode. Available functions: sqrt, sin, cos, tan, log, ln, abs, pi, e, and more.")
            SettingsLabeled(title: "Input:") {
                Picker("", selection: model.bindPref(\.calculatorInputType)) {
                    Text("Use macOS locale specified decimal separator").tag("standard")
                    Text("Use full stop (.) as decimal separator").tag("dot")
                    Text("Use comma (,) as decimal separator").tag("comma")
                }
                .labelsHidden()
                .frame(width: 330)
                Toggle("Ignore thousands grouping separator", isOn: model.bindPref(\.calculatorInputThousands))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Force the input to a particular decimal separator other than the system locale. You can also use both.")
            SettingsLabeled(title: "Output:") {
                Picker("", selection: model.bindPref(\.calculatorOutputType)) {
                    Text("Use macOS locale specified decimal separator").tag("standard")
                    Text("Use full stop (.) as decimal separator").tag("dot")
                    Text("Use comma (,) as decimal separator").tag("comma")
                }
                .labelsHidden()
                .frame(width: 330)
                Toggle("Show thousands grouping separator", isOn: model.bindPref(\.calculatorOutputThousands))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Force the output to a particular decimal separator other than the system locale. Show grouping separators for easier reading.")
            SettingsLabeled(title: "Result:") {
                Text("Return copies the result to the clipboard and pastes it into the previous application.")
                    .font(.system(size: 12))
                    .foregroundStyle(JfredColor.sub)
            }
        }
    }

    private var dictionary: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Define a Word:") {
                Toggle("", isOn: model.bindPref(\.dictionaryDefineEnabled))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                TextField("define", text: model.bindPref(\.dictionaryDefineKeyword))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
            }
            SettingsNote("Use keyword followed by a word to open the selected word in macOS Dictionary.")
            SettingsLabeled(title: "Spell a Word:") {
                Toggle("", isOn: model.bindPref(\.dictionarySpellEnabled))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                TextField("spell", text: model.bindPref(\.dictionarySpellKeyword))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
            }
            SettingsNote("Use keyword followed by a word to suggest spellings as you type, then copy the selected spelling after the action.")
            SettingsLabeled(title: "Language:") {
                Picker("", selection: model.bindPref(\.dictionaryLanguage)) {
                    Text("Default").tag("Default")
                    Text("English").tag("English")
                    Text("English (UK)").tag("English (UK)")
                    Text("French").tag("French")
                    Text("German").tag("German")
                    Text("Spanish").tag("Spanish")
                    Text("Italian").tag("Italian")
                    Text("Japanese").tag("Japanese")
                    Text("Chinese").tag("Chinese")
                }
                .labelsHidden()
                .frame(width: 220)
            }
            SettingsNote("Select the language of the words you would like to look up when using the spell and define actions.")
            SettingsLabeled(title: "Options:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Paste word on action", isOn: model.bindPref(\.dictionaryPasteOnAction))
                        .toggleStyle(.checkbox)
                    Toggle("Only show words with macOS Dictionary definition", isOn: model.bindPref(\.dictionaryOnlyDictionary))
                        .toggleStyle(.checkbox)
                }
            }
        }
    }

    private var onePassword: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "1Password:") {
                Toggle("Search 1Password items", isOn: model.bindPref(\.onePasswordEnabled))
                    .toggleStyle(.checkbox)
            }
            SettingsLabeled(title: "Status:") {
                Text(model.opItems.isEmpty ? "No items loaded. Turn this on after op item list works in Terminal." : "\(model.opItems.count) items loaded.")
                    .font(.system(size: 12))
                    .foregroundStyle(JfredColor.sub)
                Button("Reload items") { model.reloadOnePassword() }
            }
        }
    }

    private var system: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 40) {
                systemColumn(Array(SystemCommand.all.prefix(7)))
                systemColumn(Array(SystemCommand.all.dropFirst(7)))
            }
            SettingsNote("Use the specified keywords to perform the system actions. Tick a box to ask for confirmation before that command runs.")
            Divider().padding(.leading, 130)
            SettingsLabeled(title: "Eject:") {
                Picker("", selection: model.bindPref(\.ejectScope)) {
                    Text("Local Mounted Volumes").tag("local")
                    Text("All Mounted Volumes").tag("all")
                }
                .labelsHidden()
                .frame(width: 240)
            }
            SettingsNote("Removable media will show ejectable removable media such as USB flash drives, DVDs and mounted images.")
            SettingsLabeled(title: "Eject All:") {
                Toggle("", isOn: model.bindPref(\.ejectAllEnabled))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                TextField("ejectall", text: model.bindSystemKeyword("ejectall", default: "ejectall"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
            }
            SettingsLabeled(title: "Exclude:") {
                exclusionsEditor
            }
            SettingsNote("Volumes you don't want to see in the results when using the eject keyword.")
        }
    }

    private var confirmableSystemIDs: Set<String> {
        ["emptytrash", "logout", "sleep", "restart", "shutdown", "quitall", "ejectall"]
    }

    private func systemColumn(_ commands: [SystemCommand]) -> some View {
        VStack(spacing: 6) {
            ForEach(commands, id: \.id) { command in
                HStack(spacing: 8) {
                    Text(command.title)
                        .font(.system(size: 12))
                        .frame(width: 110, alignment: .trailing)
                    Toggle("", isOn: Binding(
                        get: { !model.preferences.systemDisabled.contains(command.id) },
                        set: { enabled in
                            model.preferences.systemDisabled.removeAll { $0 == command.id }
                            if !enabled { model.preferences.systemDisabled.append(command.id) }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    Toggle("", isOn: model.bindMember(\.systemConfirm, command.id))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .opacity(confirmableSystemIDs.contains(command.id) ? 1 : 0)
                        .disabled(!confirmableSystemIDs.contains(command.id))
                    TextField("keyword", text: model.bindSystemKeyword(command.id, default: command.keywords.first ?? command.id))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
            }
        }
    }

    private var exclusionsEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsCard {
                ScrollView {
                    VStack(spacing: 0) {
                        if model.preferences.ejectExclusions.isEmpty {
                            Text("None")
                                .font(.system(size: 11))
                                .foregroundStyle(JfredColor.sub)
                                .frame(maxWidth: .infinity, minHeight: 60)
                        } else {
                            ForEach(Array(model.preferences.ejectExclusions.indices), id: \.self) { index in
                                TextField("Volume name", text: model.bindElement(\.ejectExclusions, index))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .frame(height: 22)
                                Divider().opacity(0.2)
                            }
                        }
                    }
                }
                .frame(width: 460, height: 110)
            }
            HStack(spacing: 6) {
                Spacer()
                Button("+") { model.preferences.ejectExclusions.append("Volume") }
                Button("−") {
                    if !model.preferences.ejectExclusions.isEmpty { model.preferences.ejectExclusions.removeLast() }
                }
            }
            .frame(width: 460)
        }
    }

    private var terminal: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Application:") {
                Picker("", selection: model.bindPref(\.terminalApp)) {
                    Text("Terminal").tag("Terminal")
                    Text("iTerm").tag("iTerm")
                    Text("Ghostty").tag("Ghostty")
                    Text("Alacritty").tag("Alacritty")
                    Text("Custom").tag("Custom")
                }
                .labelsHidden()
                .frame(width: 220)
            }
            SettingsNote("Select Terminal or Custom. Changing the terminal here will also change the terminal used for the 'Open in Terminal' action.")
            SettingsLabeled(title: "Prefix:") {
                TextField(">", text: model.bindPref(\.terminalPrefix))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
            }
            SettingsNote("Type this character to make Jfred recognise your shell command.")
            if model.preferences.terminalApp == "Custom" {
                SettingsLabeled(title: "Custom:") {
                    TextEditor(text: model.bindPref(\.terminalCustomScript))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 420, height: 120)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.12)))
                }
                SettingsNote("Enter the AppleScript you would like to use for all Jfred terminal actions.")
            }
        }
    }

    private var largeType: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                Picker("", selection: model.bindPref(\.largeTypeBackgroundMode)) {
                    Text("Fit Large Type Background to Text").tag("fit")
                    Text("Fixed Large Type Background").tag("fixed")
                }
                .labelsHidden()
                .frame(width: 300)
            }
            ZStack {
                WallpaperArt()
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.38))
                    .frame(width: 620, height: 220)
                Text("Jfred")
                    .font(largeTypePreviewFont)
                    .foregroundStyle(.white)
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack(spacing: 24) {
                Toggle("Auto Hide Jfred when showing Large Type", isOn: model.bindPref(\.largeTypeAutoHide))
                    .toggleStyle(.checkbox)
                Toggle("Show Large Type on mouse screen", isOn: model.bindPref(\.largeTypeShowOnMouseScreen))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Use ⌘L to show the typed text as Large Type. Some result items will contextually show something other than the typed text.")
            SettingsLabeled(title: "Size:") {
                Slider(value: model.bindPref(\.largeTypeSize), in: 48...180)
                    .frame(width: 260)
                Text("\(Int(model.preferences.largeTypeSize)) pt")
                    .font(.system(size: 11))
                    .foregroundStyle(JfredColor.sub)
                    .frame(width: 44, alignment: .trailing)
            }
            SettingsLabeled(title: "Font:") {
                Picker("", selection: model.bindPref(\.largeTypeFont)) {
                    Text("System").tag("System")
                    Text("Avenir Next").tag("Avenir Next")
                    Text("Georgia").tag("Georgia")
                    Text("Menlo").tag("Menlo")
                }
                .labelsHidden()
                .frame(width: 200)
            }
        }
    }

    private var largeTypePreviewFont: Font {
        switch model.preferences.largeTypeFont {
        case "Avenir Next": return .custom("Avenir Next", size: 64)
        case "Georgia": return .custom("Georgia", size: 64)
        case "Menlo": return .custom("Menlo", size: 64)
        default: return .system(size: 64, weight: .semibold)
        }
    }

    private var previews: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Quick Look:") {
                Toggle("⇧ to Quick Look selected item", isOn: model.bindPref(\.quickLookEnabled))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Tap Shift to Quick Look the selected item in Jfred. Alternatively, use ⌘Y.")
            SettingsLabeled(title: "Previews:") {
                Toggle("Show rich file previews", isOn: model.bindPref(\.richPreviewsEnabled))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Previews are shown in the actions panel, and when navigating the file system. When disabled, the file type icon will be shown instead.")
            stringListEditor(title: "No Previews For:", hint: "public.item", keyPath: \.noPreviewTypes)
            SettingsNote("Don't load navigation / action previews for the given file types. Useful for previews which require slow network access.")
            stringListEditor(title: "No Previews In:", hint: "~/Library/", keyPath: \.noPreviewPaths)
            SettingsNote("Don't load navigation / action previews within the given path. Useful for adding slow network drives.")
        }
    }

    private func stringListEditor(title: String, hint: String, keyPath: WritableKeyPath<Preferences, [String]>) -> some View {
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
        case .contacts: "Contacts"
        case .music: "Music"
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
        case .contacts: "Search and view your Apple Address Book."
        case .music: "Take control of Music.app to find and play your favourite music, or let Jfred pick for you."
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
        case .contacts: return Color(hex: 0x2F6F8F)
        case .music: return Color(hex: 0xB03A5E)
        case .onePassword: return Color(hex: 0x2F4858)
        case .system: return Color(hex: 0x6A3D9A)
        case .terminal: return Color(hex: 0x2F2F2F)
        case .largeType: return Color(hex: 0x7A5C3E)
        case .previews: return Color(hex: 0x2F6F6F)
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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
