import AppKit
import SwiftUI
import JfredCore

extension FeaturesPane {
    var largeType: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                Picker("", selection: model.bindPref(\.largeTypeBackgroundMode)) {
                    Text("Fit Large Type Background to Text").tag("fit")
                    Text("Fixed Large Type Background").tag("fixed")
                }
                .labelsHidden()
                .frame(width: 300)
            }
            ZStack {
                WallpaperArt()
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.38))
                    .frame(width: 620, height: 220)
                Text("Jfred")
                    .font(largeTypePreviewFont)
                    .foregroundStyle(.white)
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack(spacing: 24) {
                Toggle("Auto Hide Jfred when showing Large Type", isOn: model.bindPref(\.largeTypeAutoHide))
                    .toggleStyle(.checkbox)
                Toggle("Show Large Type on mouse screen", isOn: model.bindPref(\.largeTypeShowOnMouseScreen))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Use ⌘L to show the typed text as Large Type. Some result items will contextually show something other than the typed text.")
            SettingsLabeled(title: "Size:") {
                Slider(value: model.bindPref(\.largeTypeSize), in: 48...180)
                    .frame(width: 260)
                Text("\(Int(model.preferences.largeTypeSize)) pt")
                    .font(.system(size: 11))
                    .foregroundStyle(JfredColor.sub)
                    .frame(width: 44, alignment: .trailing)
            }
            SettingsLabeled(title: "Font:") {
                Picker("", selection: model.bindPref(\.largeTypeFont)) {
                    Text("System").tag("System")
                    Text("Avenir Next").tag("Avenir Next")
                    Text("Georgia").tag("Georgia")
                    Text("Menlo").tag("Menlo")
                }
                .labelsHidden()
                .frame(width: 200)
            }
        }
    }

    var largeTypePreviewFont: Font {
        switch model.preferences.largeTypeFont {
        case "Avenir Next": return .custom("Avenir Next", size: 64)
        case "Georgia": return .custom("Georgia", size: 64)
        case "Menlo": return .custom("Menlo", size: 64)
        default: return .system(size: 64, weight: .semibold)
        }
    }

}
