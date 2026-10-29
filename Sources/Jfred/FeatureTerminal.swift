import AppKit
import SwiftUI
import JfredCore

extension FeaturesPane {
    var terminal: some View {
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

}
