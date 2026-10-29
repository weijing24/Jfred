import AppKit
import SwiftUI
import JfredCore

extension FeaturesPane {
    var defaultResults: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeled("Applications:") { Button("Options...") { model.featureSheet = .appOptions } }
            labeled("Essentials:") {
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

    var scopeList: some View {
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

}
