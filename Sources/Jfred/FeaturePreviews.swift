import AppKit
import SwiftUI
import JfredCore

extension FeaturesPane {
    var previews: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Quick Look:") {
                Toggle("⇧ to Quick Look selected item", isOn: model.bindPref(\.quickLookEnabled))
                    .toggleStyle(.checkbox)
            }
            SettingsNote("Tap Shift to Quick Look the selected item in Jfred. Alternatively, use ⌘Y.")
            stringListEditor(title: "No Previews For:", hint: "public.item", keyPath: \.noPreviewTypes)
            SettingsNote("Don't load navigation / action previews for the given file types. Useful for previews which require slow network access.")
            stringListEditor(title: "No Previews In:", hint: "~/Library/", keyPath: \.noPreviewPaths)
            SettingsNote("Don't load navigation / action previews within the given path. Useful for adding slow network drives.")
        }
    }

}
