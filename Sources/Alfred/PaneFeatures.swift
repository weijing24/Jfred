import SwiftUI
import AlfredCore

struct FeaturesPane: View {
    var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            featureList
            ScrollView {
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
                    case .contacts: contacts
                    case .music: music
                    case .onePassword: onePassword
                    case .system: system
                    case .terminal: terminal
                    case .largeType: largeType
                    case .previews: previews
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AlfredColor.canvas)
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
                                .frame(width: 28, height: 28)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.16)))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(feature.title).font(.system(size: 13, weight: .semibold))
                                Text(feature.subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .foregroundStyle(.white)
                        .background(model.feature == feature ? AlfredColor.sidebarSelected : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 248)
        .background(AlfredColor.sidebar.opacity(0.96))
    }

    private var defaultResults: some View {
        VStack(alignment: .leading, spacing: 14) {
            header("Default Results", "These are the main results Alfred presents by default, and where he looks for them.")
            labeled("Applications:") { Button("Options...") { model.featureSheet = .appOptions } }
            labeled("Essentials:") {
                HStack(spacing: 28) {
                    Toggle("Contacts", isOn: model.bindPref(\.contactsEnabled))
                    Toggle("System Settings", isOn: model.bindPref(\.systemSettingsEnabled))
                }
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
            Text("Note: Alfred works most efficiently if you only have 'Essential' items ticked and use the 'open' keyword to find files. You can also press space immediately after activating Alfred to quickly enter the file search mode.")
                .font(.system(size: 11)).foregroundStyle(AlfredColor.sub).padding(.leading, 132)
            labeled("Unintelligent:") { Toggle("Search all file types", isOn: model.bindPref(\.searchAllFileTypes)) }
            Text("WARNING: Selecting this will slow down and muddle the default search results considerably. Use 'open' and 'find' for file operations instead.")
                .font(.system(size: 11)).foregroundStyle(AlfredColor.sub).padding(.leading, 132)
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
            Text("Fallbacks are shown when Alfred is unable to find any results. If the option to intelligently show fallbacks is selected, Alfred will show the fallbacks when relevant. By default, Alfred shows Google, Amazon and Wikipedia.")
                .font(.system(size: 11)).foregroundStyle(AlfredColor.sub).padding(.leading, 132)
        }
    }

    private var scopeList: some View {
        VStack(alignment: .leading, spacing: 6) {
            List(model.preferences.scopePaths, id: \.self, selection: model.bind(\.selectedScopePath)) { path in
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill").foregroundStyle(.blue)
                    Text(path).font(.system(size: 12, design: .monospaced))
                }
                .tag(path)
            }
            .frame(height: 220)
            .padding(.leading, 132)
            HStack {
                Spacer()
                Button("+") { model.addScopeFolder() }
                Button("−") {
                    if let selectedScopePath = model.selectedScopePath { model.preferences.scopePaths.removeAll { $0 == selectedScopePath } }
                }
                Button("Reset...") { model.preferences.scopePaths = Preferences.defaultScope }
            }
            Text("These folders define where Alfred looks for files, applications and metadata. Fewer paths give more accurate results. Drop folders above from Finder or Alfred.")
                .font(.system(size: 11)).foregroundStyle(AlfredColor.sub).padding(.leading, 132)
        }
    }

    private var fileSearch: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("File Search", "Space after the hotkey, or the open and find keywords, searches files with Spotlight.")
            Stepper("Maximum results: \(model.preferences.fileSearchMax)", value: model.bindPref(\.fileSearchMax), in: 5...50)
            Toggle("Keep a file buffer (option-up adds the selected file)", isOn: model.bindPref(\.fileBufferEnabled))
            Text("Return opens every file in the buffer. ⌘Y previews the selected file with Quick Look.")
                .font(.system(size: 12)).foregroundStyle(AlfredColor.sub)
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("Universal Actions", "Modifiers on return change what the selected result does.")
            Text("Control, option, and command are set in Advanced. By default control searches the web, option searches in Finder, and command reveals a local file.")
                .foregroundStyle(AlfredColor.sub)
            LabeledContent("Copy") { Text("⌘C copies the path, URL, or subtitle") }
            LabeledContent("Large Type") { Text("⌘L") }
            LabeledContent("Quick Look") { Text("⌘Y") }
            LabeledContent("Complete") { Text("Tab inserts the selected title") }
        }
    }

    private var webSearch: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("Web Search", "Keywords open a search. Fallbacks are used when nothing else matches.")
            ForEach(Array(model.preferences.webSearches.enumerated()), id: \.element.id) { index, _ in
                HStack {
                    Toggle("", isOn: model.bindWeb(index, \.enabled)).labelsHidden()
                    TextField("Title", text: model.bindWeb(index, \.title)).frame(width: 120)
                    TextField("Keyword", text: model.bindWeb(index, \.keyword)).frame(width: 80)
                    TextField("URL, use {query}", text: model.bindWeb(index, \.urlTemplate))
                    Toggle("Fallback", isOn: model.bindWeb(index, \.fallback))
                }
            }
            Button("Add search") {
                model.preferences.webSearches.append(WebSearch(id: UUID().uuidString, title: "Search", keyword: "s", urlTemplate: "https://www.google.com/search?q={query}", enabled: true, fallback: false, symbol: "magnifyingglass"))
            }
        }
    }

    private var bookmarks: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("Web Bookmarks", "Safari and Chrome bookmarks are mixed into default results.")
            Toggle("Safari bookmarks", isOn: model.bindPref(\.safariBookmarks))
            Toggle("Google Chrome bookmarks", isOn: model.bindPref(\.chromeBookmarks))
            Text("\(model.links.count) bookmarks indexed. The tabs keyword also reads open tabs and recent history.")
                .foregroundStyle(AlfredColor.sub)
            Button("Reload bookmarks") { model.reloadLinks() }
        }
    }

    private var clipboard: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("Clipboard History", "Keyword clip, or clipboard, pastes a previous copy.")
            Toggle("Keep clipboard history", isOn: model.bindPref(\.clipboardEnabled))
            Stepper("Remember \(model.preferences.clipboardLimit) items", value: model.bindPref(\.clipboardLimit), in: 20...1000, step: 10)
            Button("Clear clipboard history") { model.clearClipboard() }
            ForEach(model.clips.prefix(8)) { clip in
                Text(clip.text.replacingOccurrences(of: "\n", with: " ")).lineLimit(1).font(.system(size: 12))
            }
        }
    }

    private var snippets: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("Snippets", "Type a keyword and space anywhere to expand it. Accessibility permission is required.")
            Toggle("Expand snippets while typing", isOn: model.bindPref(\.snippetsEnabled))
            ForEach(Array(model.snippets.enumerated()), id: \.element.id) { index, _ in
                HStack {
                    TextField("Name", text: model.bindSnippet(index, \.name)).frame(width: 140)
                    TextField("Keyword", text: model.bindSnippet(index, \.keyword)).frame(width: 100)
                    TextField("Text, {date} {time} {iso}", text: model.bindSnippet(index, \.text))
                }
            }
            HStack {
                Button("Add snippet") { model.snippets.append(Snippet(name: "New snippet", keyword: ";new", text: "")) }
                Button("Remove last") { if !model.snippets.isEmpty { model.snippets.removeLast() } }
            }
            Text("{date}, {time}, and {iso} are filled in when the snippet expands.")
                .font(.system(size: 12)).foregroundStyle(AlfredColor.sub)
        }
    }

    private var calculator: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("Calculator", "Type an expression such as (2+2)*3 or sqrt(9).")
            Toggle("Calculate in the default results", isOn: model.bindPref(\.calculatorEnabled))
            Text("Return pastes the result into the previous app. Functions: sqrt, sin, cos, tan, log, ln, abs, pi, e.")
                .foregroundStyle(AlfredColor.sub)
        }
    }

    private var dictionary: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("Dictionary", "define word uses the macOS dictionary.")
            Toggle("Enable define", isOn: model.bindPref(\.dictionaryEnabled))
        }
    }

    private var contacts: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("Contacts", "Names, emails, and phone numbers from Contacts.")
            Toggle("Include contacts in default results", isOn: model.bindPref(\.contactsEnabled))
            Text("\(model.contacts.count) contacts loaded.")
                .foregroundStyle(AlfredColor.sub)
            Button("Reload contacts") { model.reloadContacts() }
        }
    }

    private var music: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("Music", "play, next, previous, and now playing control the Music app.")
            Toggle("Show music commands", isOn: model.bindPref(\.musicEnabled))
        }
    }

    private var onePassword: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("1Password", "Uses the op command-line tool when it is installed and signed in.")
            Toggle("Search 1Password items", isOn: model.bindPref(\.onePasswordEnabled))
            Text(model.opItems.isEmpty ? "No items loaded. Turn this on after op item list works in Terminal." : "\(model.opItems.count) items.")
                .foregroundStyle(AlfredColor.sub)
            Button("Reload items") { model.reloadOnePassword() }
        }
    }

    private var system: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("System", "Search for sleep, lock, restart, empty trash, eject, dark mode, and the other system commands.")
            ForEach(SystemCommand.all, id: \.id) { command in
                HStack {
                    Image(systemName: command.symbol).frame(width: 22)
                    Text(command.title)
                    Spacer()
                    Text(command.keywords.joined(separator: ", ")).foregroundStyle(.secondary).font(.system(size: 11))
                }
            }
        }
    }

    private var terminal: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("Terminal", "Prefix a command with > to run it in a terminal window.")
            Picker("Terminal app", selection: model.bindPref(\.terminalApp)) {
                Text("Terminal").tag("Terminal")
                Text("iTerm").tag("iTerm")
                Text("Ghostty").tag("Ghostty")
                Text("Alacritty").tag("Alacritty")
            }
            .frame(width: 280)
        }
    }

    private var largeType: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("Large Type", "⌘L shows the selected result in large type. Click or press escape to dismiss it.")
            Slider(value: model.bindPref(\.largeTypeSize), in: 48...180) { Text("Size") }
            Picker("Font", selection: model.bindPref(\.largeTypeFont)) {
                Text("System").tag("System")
                Text("Avenir Next").tag("Avenir Next")
                Text("Georgia").tag("Georgia")
                Text("Menlo").tag("Menlo")
            }
            .frame(width: 280)
        }
    }

    private var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("Previews", "⌘Y opens Quick Look for a selected file.")
            Toggle("Enable Quick Look", isOn: model.bindPref(\.quickLookEnabled))
        }
    }

    private func header(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 22, weight: .semibold))
            Text(text).foregroundStyle(AlfredColor.sub)
        }
        .padding(.bottom, 6)
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
