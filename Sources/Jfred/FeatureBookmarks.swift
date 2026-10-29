import AppKit
import SwiftUI
import JfredCore

extension FeaturesPane {
    var bookmarks: some View {
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

}
