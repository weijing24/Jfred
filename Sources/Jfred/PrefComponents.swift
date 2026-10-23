import SwiftUI

/// Alfred's segmented tab strip, used at the top of feature pages.
struct SettingsTabBar: View {
    @Binding var selection: String
    var tabs: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    Text(tab)
                        .font(.system(size: 13))
                        .foregroundStyle(selection == tab ? JfredColor.ink : JfredColor.sub)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selection == tab ? Color.white : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: 0xE0E0E0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
    }
}

/// White rounded table / list card, matching Alfred's content panels.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
            )
    }
}

/// Grey inset panel that groups a table and its toolbar, as on Alfred's pages.
struct SettingsPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: 0xE5E5E5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
    }
}

/// Small rounded search field used above tables.
struct SettingsFilterField: View {
    var placeholder: String
    @Binding var text: String
    var width: CGFloat = 242

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: 0x7A7A7A))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 7)
        .frame(width: width, height: 24)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
    }
}

/// Right-aligned form label + controls on Alfred's 120pt label grid.
struct SettingsLabeled<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(JfredColor.ink)
                .frame(width: 120, alignment: .trailing)
            content()
            Spacer(minLength: 0)
        }
    }
}

/// Alfred's small grey explanation text, aligned with the control column.
struct SettingsNote: View {
    var text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(JfredColor.sub)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 130)
    }
}
