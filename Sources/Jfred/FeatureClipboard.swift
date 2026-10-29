import AppKit
import SwiftUI
import JfredCore

extension FeaturesPane {
    var clipboard: some View {
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

    var clipboardHistoryTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Clipboard History:") {
                HStack(alignment: .top, spacing: 12) {
                    clipKeepBox("Keep Plain Text", isOn: model.bindPref(\.clipboardKeepText), retention: model.bindPref(\.clipboardRetentionText), enabled: true)
                    clipKeepBox("Keep Images", isOn: model.bindPref(\.clipboardKeepImages), retention: model.bindPref(\.clipboardRetentionImages), enabled: true)
                    clipKeepBox("Keep File Lists", isOn: model.bindPref(\.clipboardKeepFiles), retention: model.bindPref(\.clipboardRetentionFiles), enabled: true)
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
                Toggle("", isOn: model.bindPref(\.clipboardClearKeywordEnabled))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
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

    var clipboardMergingTab: some View {
        VStack(alignment: .leading, spacing: 14) {
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

    var clipboardAdvancedTab: some View {
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
            SettingsLabeled(title: "Behaviour:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Move items to top of clipboard history when used", isOn: model.bindPref(\.clipboardMoveToTopOnUse))
                        .toggleStyle(.checkbox)
                    Toggle("Clear clipboard history when Jfred quits", isOn: model.bindPref(\.clipboardClearOnQuit))
                        .toggleStyle(.checkbox)
                }
            }
            SettingsNote("The clipboard history is stored locally with 0600 permissions inside Jfred's support folder. Items copied from 1Password, Keychain Access, Passwords, Wallet and SecurityAgent are never stored. Enable clearing on quit if you don't want it to persist.")
            stringListEditor(title: "Ignore Apps:", hint: "Application name", keyPath: \.clipboardIgnoreApps)
            SettingsNote("Drop the applications you would like Jfred to ignore into the list, or add their exact names. Only focusable applications can be ignored.")
        }
    }

    func removeDuplicateClips() {
        var seen = Set<String>()
        model.clips.removeAll { clip in
            !seen.insert(clip.text).inserted
        }
    }

    func clipKeepBox(_ title: String, isOn: Binding<Bool>, retention: Binding<String>, enabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: isOn)
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
                .disabled(!enabled)
            Picker("", selection: retention) {
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

}
