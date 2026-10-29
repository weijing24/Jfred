import AppKit
import SwiftUI
import JfredCore

extension FeaturesPane {
    var dictionary: some View {
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
            SettingsLabeled(title: "Options:") {
                Toggle("Paste word on action", isOn: model.bindPref(\.dictionaryPasteOnAction))
                    .toggleStyle(.checkbox)
            }
        }
    }

}
