import AppKit
import SwiftUI
import JfredCore

extension FeaturesPane {
    var calculator: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsLabeled(title: "Calculator:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Enable standard calculator", isOn: model.bindPref(\.calculatorEnabled))
                        .toggleStyle(.checkbox)
                    Toggle("Enable advanced calculator with keyword '='", isOn: model.bindPref(\.calculatorAdvanced))
                        .toggleStyle(.checkbox)
                }
            }
            SettingsNote("= before your calculation enables advanced mode. Available functions: sqrt, sin, cos, tan, log, ln, abs, pi, e, and more.")
            SettingsLabeled(title: "Result:") {
                Text("Return copies the result to the clipboard and pastes it into the previous application.")
                    .font(.system(size: 12))
                    .foregroundStyle(JfredColor.sub)
            }
        }
    }

}
