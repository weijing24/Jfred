import AppKit
import SwiftUI
import JfredCore

extension FeaturesPane {
    var actions: some View {
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
                SettingsNote("Actions are generated per result type: apps/files, URLs, clipboard items and calculations.")
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
                    Text("⌥⌘\\")
                        .font(.system(size: 12, design: .monospaced))
                }
                SettingsNote("⌥⌘\\ shows actions for the current selection in macOS. The shortcut is fixed.")
                if !model.selectionHotkeyWarning.isEmpty {
                    Text(model.selectionHotkeyWarning)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .padding(.leading, 130)
                }
                SettingsLabeled(title: "Action Ordering:") {
                    Toggle("Sort actions by last used per type", isOn: model.bindPref(\.uaSortByUsage))
                        .toggleStyle(.checkbox)
                }
                SettingsNote("By default, Jfred fixes the order of actions. If you prefer, Jfred will order actions based on your usage per type actioned.")
            }
        }
    }

    func actionRow(_ title: String, _ shortcut: String, _ detail: String) -> some View {
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

    func modifierPicker(_ title: String, selection: Binding<String>) -> some View {
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

}
