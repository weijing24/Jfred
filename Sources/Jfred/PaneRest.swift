import SwiftUI
import JfredCore

struct AppearancePane: View {
    var model: AppModel
    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(LauncherTheme.all) { theme in
                        Button {
                            model.preferences.themeID = theme.id
                        } label: {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(theme.selected)
                                    .frame(width: 18, height: 28)
                                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.4)))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(theme.name).font(.system(size: 13, weight: .semibold))
                                    Text(theme.detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .foregroundStyle(.white)
                            .background(model.preferences.themeID == theme.id ? Color.white.opacity(0.22) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: 250)
            .jfredSidebar(tint: JfredColor.sidebarDeep)
            ZStack {
                WallpaperArt()
                PreviewLauncher(theme: LauncherTheme.by(id: model.preferences.themeID))
                    .padding(.top, 30)
            }
        }
    }
}

struct RemotePane: View {
    var model: AppModel
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(RemoteCategory.allCases) { category in
                    Button { model.remoteCategory = category } label: {
                        HStack(spacing: 8) {
                            Image(systemName: category.symbol).frame(width: 22)
                            VStack(alignment: .leading) {
                                Text(category.title).font(.system(size: 13, weight: .semibold))
                                Text(category.subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.82))
                            }
                            Spacer()
                        }
                        .padding(8)
                        .foregroundStyle(.white)
                        .background(model.remoteCategory == category ? Color.white.opacity(0.22) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .frame(width: 250)
            .jfredSidebar(tint: JfredColor.sidebarDeep)
            ZStack {
                Color(hex: 0x161616)
                VStack(spacing: 18) {
                    ZStack {
                        HoodMark().frame(width: 180, height: 140)
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.25))
                            .offset(x: 70, y: -30)
                    }
                    Text(model.preferences.remoteEnabled ? "Remote server is running" : "Enable Remote Server")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    if model.preferences.remoteEnabled {
                        Text(model.remoteWarning.isEmpty ? "http://127.0.0.1:\(model.preferences.remotePort)/?token=\(model.preferences.remoteToken)" : model.remoteWarning)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.82))
                            .textSelection(.enabled)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable Jfred Remote Server", isOn: model.bindPref(\.remoteEnabled))
                    .padding(.top, 18)
                Text(model.preferences.remoteEnabled ? "Server running" : "Server Stopped")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
                Text(model.preferences.remoteLocalOnly ? "127.0.0.1" : "All interfaces")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
                Toggle("This Mac only", isOn: model.bindPref(\.remoteLocalOnly))
                Stepper("Port \(model.preferences.remotePort)", value: model.bindPref(\.remotePort), in: 1024...65535)
                Text("Token \(model.preferences.remoteToken)")
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                VStack(spacing: 8) {
                    Text("Jfred Remote for iOS")
                        .font(.system(size: 16, weight: .semibold))
                    Text("This local page is your command centre. It stays on this Mac and asks for the token above.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Open Remote Page") {
                        let url = "http://127.0.0.1:\(model.preferences.remotePort)/?token=\(model.preferences.remoteToken)"
                        if let link = URL(string: url) { NSWorkspace.shared.open(link) }
                    }
                    .disabled(!model.preferences.remoteEnabled)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 16)
            .frame(width: 280)
            .background(Color.white)
        }
    }
}

struct AdvancedPane: View {
    var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 4) {
                    Text("General and global tweaking of Jfred").font(.system(size: 16, weight: .semibold))
                    Text("Mostly because you won't be touching this stuff much, and it doesn't fit elsewhere in Jfred's preferences ;)")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        labeled("Files / Apps:") {
                            HStack {
                                Button("Clear Application Cache") { model.clearAppCache() }
                                Button("Rebuild macOS Metadata") { model.rebuildMetadata() }
                            }
                        }
                        note("Applications are cached for the fastest possible response. The cache manages itself, but if something funny is going on, clearing the cache may help. Reindex macOS rebuilds your Mac's low level file index.")
                        labeled("History:") {
                            VStack(alignment: .leading) {
                                Toggle("Store typed query", isOn: model.bindPref(\.storeTypedQuery))
                                Toggle("Show latest query if within 5 minutes", isOn: model.bindPref(\.showLatestQuery))
                            }
                        }
                        note("Press the up arrow with an empty query field to view up to 20 of your last typed queries.")
                        labeled("Learning:") {
                            HStack {
                                Toggle("Top Result Keyword Latching", isOn: model.bindPref(\.topResultLatching))
                                Button("Clear Knowledge") { model.clearKnowledge() }
                            }
                        }
                        labeled("Notifications:") {
                            VStack(alignment: .leading) {
                                Toggle("Remove when clicked", isOn: model.bindPref(\.removeNotificationWhenClicked))
                                Toggle("Show notification icons", isOn: model.bindPref(\.showNotificationIcons))
                            }
                        }
                        labeled("Network:") {
                            Toggle("Use macOS http proxy settings for scripts", isOn: model.bindPref(\.useHTTPProxy))
                        }
                        labeled("Selection Hotkeys:") {
                            Picker("", selection: model.bindPref(\.selectionHotkeyMode)) {
                                Text("Leave selected item in clipboard").tag("leave")
                                Text("Restore previous clipboard").tag("restore")
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        note("Jfred uses the clipboard when pasting the selected item. You can restore the previous clipboard contents afterwards.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 16) {
                        labeled("Force Keyboard:") {
                            TextField("Leave blank", text: model.bindPref(\.forceKeyboard))
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 220)
                        }
                        note("This will force Jfred to use the specified keyboard locale. Leave blank (default) and Jfred won't switch keyboards.")
                        labeled("Action Modifier:") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("⌘ + number to action result items").font(.system(size: 12))
                                modifierRow("ctrl", model.bindPref(\.modifierControl))
                                modifierRow("option", model.bindPref(\.modifierOption))
                                modifierRow("cmd", model.bindPref(\.modifierCommand))
                            }
                        }
                        note("Perform actions on core results using modifiers. Reveal in Finder works for local files and apps.")
                        labeled("Syncing:") {
                            Text(model.preferences.syncFolder.isEmpty ? supportLabel : model.preferences.syncFolder)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        note("This folder can be local or under the control of a syncing service. Jfred keeps its own JfredLocal folder inside it, separate from the official Jfred preferences.")
                        HStack {
                            Button("Set preferences folder...") { model.chooseSupportFolder() }
                            Button("Reveal in Finder") { model.revealSupportFolder() }
                        }
                        .padding(.leading, 126)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var supportLabel: String {
        SupportPaths.directory(syncFolder: "").path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).frame(width: 118, alignment: .trailing)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 126)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func modifierRow(_ name: String, _ selection: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(name).frame(width: 44, alignment: .trailing)
            Picker("", selection: selection) {
                Text("Search with default web search").tag("web")
                Text("Search with Finder").tag("finder")
                Text("Reveal in Finder (if local)").tag("reveal")
                Text("Primary action").tag("primary")
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct UsagePane: View {
    var model: AppModel
    var body: some View {
        let stats = UsageMath.counts(events: model.usage, days: 28)
        VStack(spacing: 8) {
            HStack {
                Text(headline(stats))
                    .font(.system(size: 14))
                Spacer()
                Button("Copy Stats") {
                    let board = NSPasteboard.general
                    board.clearContents()
                    board.setString(headline(stats), forType: .string)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            legend
            UsageChart(series: stats.series)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .background(Color.white)
    }

    private func headline(_ stats: (days: [Date], series: [String: [Int]], total: Int, average: Double, since: Date?)) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let since = stats.since.map { formatter.string(from: $0) } ?? "today"
        return "Since \(since), Jfred has been used \(stats.total) times. Average \(String(format: "%.1f", stats.average)) times per day."
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach(UsageEvent.categories, id: \.self) { category in
                HStack(spacing: 4) {
                    Circle().fill(usageColor(category)).frame(width: 8, height: 8)
                    Text(category.capitalized).font(.system(size: 11))
                }
            }
        }
    }
}

struct UsageChart: View {
    var series: [String: [Int]]
    private let order = UsageEvent.categories

    var body: some View {
        Canvas { context, size in
            let days = series[order[0]]?.count ?? 28
            guard days > 1 else { return }
            var stacked = Array(repeating: 0.0, count: days)
            var layers: [[Double]] = []
            for category in order {
                let values = series[category] ?? Array(repeating: 0, count: days)
                var next = stacked
                for index in 0..<days {
                    next[index] += Double(values.indices.contains(index) ? values[index] : 0)
                }
                layers.append(next)
                stacked = next
            }
            let peak = max(stacked.max() ?? 1, 1)
            func point(_ index: Int, _ value: Double) -> CGPoint {
                let x = size.width * CGFloat(index) / CGFloat(days - 1)
                let y = size.height - 18 - (size.height - 28) * CGFloat(value / peak)
                return CGPoint(x: x, y: y)
            }
            for (layerIndex, layer) in layers.enumerated().reversed() {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height - 18))
                for index in 0..<days { path.addLine(to: point(index, layer[index])) }
                path.addLine(to: CGPoint(x: size.width, y: size.height - 18))
                path.closeSubpath()
                context.fill(path, with: .color(usageColor(order[layerIndex]).opacity(0.9)))
            }
            let label = Text("28 days ago").font(.system(size: 11)).foregroundColor(.secondary)
            context.draw(label, at: CGPoint(x: 36, y: size.height - 8))
            context.draw(Text("Now").font(.system(size: 11)).foregroundColor(.secondary), at: CGPoint(x: size.width - 16, y: size.height - 8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

func usageColor(_ category: String) -> Color {
    switch category {
    case "general": Color(hex: 0x7B3FA0)
    case "expansion": Color(hex: 0x2BB3C7)
    case "clipboard": Color(hex: 0xC47A4A)
    case "navigation": Color(hex: 0xD15BA0)
    case "action": Color(hex: 0xC6C14A)
    case "music": Color(hex: 0xD24B4B)
    case "remote": Color(hex: 0x3A74D8)
    default: Color(hex: 0x8FCE4A)
    }
}

struct UpdatePane: View {
    var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("You are using Jfred \(AppRelease.version)")
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(white: 0.94))
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Change Log").font(.system(size: 28, weight: .bold))
                    Text("This is a local build matching the Jfred preferences layout. It does not download updates from jfredapp.com.")
                        .foregroundStyle(.secondary)
                    Divider()
                    Text("Jfred \(AppRelease.version)").font(.system(size: 22, weight: .bold))
                    Text("Local build")
                    bullet("Hotkey launcher with themes, file search, applications, and system settings")
                    bullet("Keywords for workflows, web search, clipboard, snippets, calculator, and dictionary")
                    bullet("Built-in actions for windows, processes, Chrome profiles, browser tabs, and system commands")
                    bullet("Preferences for scope, fallbacks, snippets, usage, and a token-gated remote page")
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                HStack {
                    Text("Automatically check for")
                    Picker("", selection: model.bindPref(\.autoUpdateCheck)) {
                        Text("updates").tag("updates")
                        Text("pre-releases").tag("prereleases")
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                Spacer()
                Button("Up to date") {}
                    .disabled(true)
            }
            .padding(12)
            .background(Color(white: 0.95))
        }
        .background(Color.white)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
}
