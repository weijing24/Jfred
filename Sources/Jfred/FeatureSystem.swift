import AppKit
import SwiftUI
import JfredCore

extension FeaturesPane {
    var system: some View {
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

    var confirmableSystemIDs: Set<String> {
        ["emptytrash", "logout", "sleep", "restart", "shutdown", "quitall", "ejectall"]
    }

    func systemColumn(_ commands: [SystemCommand]) -> some View {
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

    var exclusionsEditor: some View {
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

}
