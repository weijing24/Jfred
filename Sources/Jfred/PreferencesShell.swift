import SwiftUI
import JfredCore

struct PreferencesShell: View {
    var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            IconRail(model: model)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(hex: 0xECECEC))
        .preferredColorScheme(.light)
        .background(WindowReader { window in
            window.identifier = NSUserInterfaceItemIdentifier("preferences")
            window.title = ""
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
            window.toolbarStyle = .unifiedCompact
            window.titlebarSeparatorStyle = .none
            window.backgroundColor = NSColor(JfredColor.canvas)
            window.setContentSize(NSSize(width: 1180, height: 766))
            if let screen = window.screen ?? NSScreen.main {
                let visible = screen.visibleFrame
                var frame = window.frame
                frame.origin.x = max(visible.minX, min(frame.origin.x, visible.maxX - frame.width))
                frame.origin.y = max(visible.minY, min(frame.origin.y, visible.maxY - frame.height))
                window.setFrame(frame, display: false)
            }
            model.notePreferencesWindow(window)
        })
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0x7A7A7A))
                    TextField("Search Preferences", text: model.bind(\.prefsQuery))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .frame(width: 420)
                }
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xE3E3E3)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.10), lineWidth: 1))
            }
        }
        .onChange(of: model.preferences) { old, _ in model.preferencesChanged(from: old) }
        .onChange(of: model.workflows) { _, _ in model.workflowsChanged() }
        .onChange(of: model.snippets) { _, _ in model.snippetsChanged() }
    }

    @ViewBuilder private var detail: some View {
        if !model.prefsQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            PreferenceSearchList(model: model)
        } else {
            switch model.section {
            case .general: GeneralPane(model: model)
            case .features: FeaturesPane(model: model)
            case .workflows: WorkflowsPane(model: model)
            case .appearance: AppearancePane(model: model)
            case .remote: RemotePane(model: model)
            case .advanced: AdvancedPane(model: model)
            case .powerpack: PowerpackPane(model: model)
            case .usage: UsagePane(model: model)
            case .help: HelpPane(model: model)
            case .update: UpdatePane(model: model)
            }
        }
    }
}

struct IconRail: View {
    var model: AppModel
    private var top: [PrefSection] { [.general, .features, .workflows, .appearance, .remote, .advanced] }
    private var bottom: [PrefSection] { [.powerpack, .usage, .help, .update] }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(top) { section in
                railButton(section)
            }
            Spacer(minLength: 12)
            ForEach(bottom) { section in
                railButton(section)
            }
        }
        .padding(.bottom, 10)
        .frame(width: 82)
        .frame(maxHeight: .infinity)
        .jfredSidebar(tint: JfredColor.sidebar)
        .layoutPriority(2)
    }

    private func railButton(_ section: PrefSection) -> some View {
        Button {
            model.section = section
        } label: {
            VStack(spacing: 5) {
                if section == .general {
                    HoodMark().frame(width: 30, height: 28)
                } else {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: section.symbol)
                            .font(.system(size: 22, weight: .regular))
                            .frame(height: 28)
                        if section == .update, model.updateReady {
                            Circle()
                                .fill(Color(hex: 0xFF5A5A))
                                .frame(width: 7, height: 7)
                                .offset(x: 3, y: 0)
                        }
                    }
                }
                Text(section.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(model.section == section ? Color.white.opacity(0.20) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PreferenceSearchList: View {
    var model: AppModel
    private var hits: [PreferenceHit] {
        let q = model.prefsQuery.trimmingCharacters(in: .whitespaces)
        return PreferenceIndex.hits.filter {
            $0.title.localizedCaseInsensitiveContains(q) || $0.detail.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        List(hits) { hit in
            Button {
                model.section = hit.section
                if let feature = hit.feature { model.feature = feature }
                model.prefsQuery = ""
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.title).font(.system(size: 14, weight: .medium))
                    Text(hit.detail).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .scrollContentBackground(.hidden)
    }
}

struct GeneralPane: View {
    var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(AppRelease.version)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0x8A8A8A))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            form
                .padding(.top, 44)
            Spacer(minLength: 0)
            NewsletterBanner(model: model)
        }
        .background(Color(hex: 0xECECEC))
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            FormRow(label: "Startup:") {
                HStack(spacing: 12) {
                    Toggle("Launch Jfred at login", isOn: model.bindPref(\.launchAtLogin))
                    Button("Quit Jfred") { model.quit() }
                }
            }
            HelpNote(text: "If selected, Jfred will still launch at login after using the \"Quit Jfred\" button.")
            FormRow(label: "Jfred Hotkey:") {
                HStack(spacing: 8) {
                    ZStack {
                        HotkeyGlyphs(hotkey: model.preferences.hotkey)
                        HotkeyCapture(
                            onSet: { code, flags in
                                model.preferences.hotkey = Hotkey(keyCode: code, modifiers: flags)
                            },
                            onFocus: { focused in
                                model.hotkeyFieldFocused = focused
                                if focused {
                                    HotkeyCenter.shared.suspend()
                                } else {
                                    model.applyHotkeys()
                                }
                            }
                        )
                    }
                    .frame(width: 280, height: 26)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(model.hotkeyFieldFocused ? Color(nsColor: .keyboardFocusIndicatorColor) : JfredColor.line, lineWidth: model.hotkeyFieldFocused ? 2 : 1)
                    )
                    Button {
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.plain)
                    .help("Click the field, then press a key or a modifier plus a key. Escape cancels.")
                }
            }
            HelpNote(text: model.hotkeyWarning.isEmpty ? "Click the field, then press a key combination such as ⌥Space or ⌘Space. Escape cancels." : model.hotkeyWarning)
            FormRow(label: "Where are you:") {
                Picker("", selection: model.bindPref(\.location)) {
                    ForEach(Preferences.locations, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 280)
            }
            HStack {
                Spacer().frame(width: 142)
                Toggle("Use .com for Google searches", isOn: model.bindPref(\.useDotCom))
            }
            HelpNote(text: "This tells Jfred which websites to use for web searching such as amazon.ca or ebay.com.")
            FormRow(label: "Permissions:") {
                Button("Request Permissions...") { model.requestPermissions() }
            }
            HelpNote(text: "Jfred requires certain permissions to enable him to automate your Mac. This button will help you enable these permissions.")
            FormRow(label: "Menu bar:") {
                Toggle("Show menu bar icon", isOn: Binding(get: { model.showStatusItem }, set: { model.showStatusItem = $0 }))
            }
            FormRow(label: "Launcher:") {
                Button("Import Launcher Settings") { model.importLauncherSettings() }
            }
            HelpNote(text: model.importNote.isEmpty ? "Copies this Mac's launcher settings into Jfred and reads that copy. The original folder is left unchanged. Built-in workflow keywords are reset to match." : model.importNote)
        }
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct NewsletterBanner: View {
    var model: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            HoodMark()
                .frame(width: 128, height: 120)
                .padding(.leading, 38)
            VStack(alignment: .leading, spacing: 8) {
                Text("Jfred Newsletter")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    TextField("Your Email", text: model.bindPref(\.newsletterEmail))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(.horizontal, 8)
                        .frame(width: 260, height: 24)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color.white))
                    Button(model.preferences.newsletterEmail.isEmpty ? "Subscribe" : "Saved") { model.saveNewsletterEmail() }
                    .buttonStyle(.bordered)
                }
                Text("For Jfred updates, tips and sneak peeks, sign up for our occasional newsletter. The address stays on this Mac; Jfred does not send it anywhere.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: 380, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 18) {
                    Label("Twitter", systemImage: "bird")
                    Label("Website", systemImage: "globe")
                }
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 2)
            }
            Spacer(minLength: 20)
        }
        .frame(height: 132)
        .background(Color(hex: 0x3B0B5C))
    }
}


/// Glass capsule for the preferences search field.
private struct ToolbarSearchBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content
                .background(Capsule().fill(Color(hex: 0xE3E3E3)))
                .overlay(Capsule().stroke(Color.black.opacity(0.10), lineWidth: 1))
        }
    }
}
