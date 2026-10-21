import SwiftUI
import JlfredCore

struct PreferencesShell: View {
    var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            IconRail(model: model)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(JlfredColor.canvas)
        .preferredColorScheme(model.section == .workflows ? .dark : .light)
        .background(WindowReader { window in
            window.identifier = NSUserInterfaceItemIdentifier("preferences")
            window.title = "Jlfred Preferences"
            window.titlebarAppearsTransparent = false
            window.setContentSize(NSSize(width: 1120, height: 720))
        })
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search Preferences", text: model.bind(\.prefsQuery))
                        .textFieldStyle(.plain)
                        .frame(width: 180)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.55)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.12)))
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
            case .usage: UsagePane(model: model)
            case .update: UpdatePane(model: model)
            }
        }
    }
}

struct IconRail: View {
    var model: AppModel
    private var top: [PrefSection] { [.general, .features, .workflows, .appearance, .remote, .advanced] }
    private var bottom: [PrefSection] { [.usage, .update] }

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
        .padding(.vertical, 8)
        .frame(width: 86)
        .frame(maxHeight: .infinity)
        .background(JlfredColor.sidebar)
    }

    private func railButton(_ section: PrefSection) -> some View {
        Button {
            model.section = section
        } label: {
            VStack(spacing: 4) {
                if section == .general {
                    BowlerHat(showsGlass: true).frame(width: 28, height: 26)
                } else {
                    Image(systemName: section.symbol)
                        .font(.system(size: 20))
                        .frame(height: 26)
                }
                Text(section.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(model.section == section ? JlfredColor.sidebarSelected : Color.clear)
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
        .background(JlfredColor.canvas)
    }
}

struct GeneralPane: View {
    var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                JlfredColor.canvas
                DamaskBackground()
                VStack(alignment: .leading, spacing: 0) {
                    Text(AppRelease.version)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0x8A8A8A))
                        .padding(.top, 8)
                        .padding(.leading, 12)
                    Spacer(minLength: 0)
                    form
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            FormRow(label: "Startup:") {
                HStack(spacing: 12) {
                    Toggle("Launch Jlfred at login", isOn: model.bindPref(\.launchAtLogin))
                    Button("Quit Jlfred") { NSApp.terminate(nil) }
                }
            }
            HelpNote(text: "If selected, Jlfred will still launch at login after using the \"Quit Jlfred\" button.")
            FormRow(label: "Jlfred Hotkey:") {
                HStack(spacing: 8) {
                    ZStack {
                        HotkeyGlyphs(hotkey: model.preferences.hotkey)
                        HotkeyCapture { code, flags in
                            model.preferences.hotkey = Hotkey(keyCode: code, modifiers: flags)
                        }
                    }
                    .frame(width: 280, height: 26)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(JlfredColor.line))
                    Button {
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.plain)
                    .help("Click the field and type the hotkey you would like to use to show Jlfred.")
                }
            }
            HelpNote(text: model.hotkeyWarning.isEmpty ? "Select this field and type the hotkey you would like to use to show Jlfred." : model.hotkeyWarning)
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
            HelpNote(text: "This tells Jlfred which websites to use for web searching such as amazon.ca or ebay.com.")
            FormRow(label: "Permissions:") {
                Button("Request Permissions...") { model.requestPermissions() }
            }
            HelpNote(text: "Jlfred requires certain permissions to enable him to automate your Mac. This button will help you enable these permissions.")
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }
}
