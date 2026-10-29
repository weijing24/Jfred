import AppKit
import SwiftUI
import JfredCore

extension FeaturesPane {
    var fileSearch: some View {
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

    var fileSearchSearchTab: some View {
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

    var fileSearchNavigationTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Previous Path:") {
                Text("Use this hotkey or keyword to show the file browser for the last browsed path from the results.")
                    .font(.system(size: 12))
                    .foregroundStyle(JfredColor.sub)
                    .frame(maxWidth: 480, alignment: .leading)
            }
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

    var fileSearchBufferTab: some View {
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
        }
    }

    var fileSearchAdvancedTab: some View {
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

    var hiddenTypeNames: [String] {
        ["Emails", "Contacts", "Calendar", "Bookmarks", "History", "Messages", "Images", "Music", "Plist files", "Source files"]
    }

    func keywordBlock(_ title: String, _ note: String, keyword: Binding<String>, enabled: Binding<Bool>) -> some View {
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

}
