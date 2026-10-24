import SwiftUI

/// Alfred's segmented tab strip, used at the top of feature pages.
struct SettingsTabBar: View {
    @Binding var selection: String
    var tabs: [String]

    var body: some View {
        HStack(spacing: 1) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    Text(tab)
                        .font(.system(size: 13))
                        .foregroundStyle(selection == tab ? JfredColor.ink : JfredColor.sub)
                        .padding(.horizontal, 15)
                        .frame(height: 23)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(selection == tab ? Color.white : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(hex: 0xE2E1E0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.black.opacity(0.09), lineWidth: 1)
        )
    }
}

/// Flat white rounded table / list card, matching Alfred's content panels.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        content()
            .background(Color.white)
            .clipShape(shape)
            .overlay(shape.stroke(Color.black.opacity(0.10), lineWidth: 1))
    }
}

/// Light inset panel that groups a table and its toolbar, as on Alfred's pages.
struct SettingsPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(hex: 0xF2F2F2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
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
        .padding(.horizontal, 9)
        .frame(width: width, height: 26)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white)
        )
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

/// Grey page header used by every feature page (title, subtitle, help).
struct PageHeaderBand: View {
    var icon: String
    var tint: Color
    var title: String
    var subtitle: String
    var help: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(JfredColor.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(JfredColor.sub)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let help {
                Button(action: help) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 21))
                        .foregroundStyle(Color(hex: 0x8A8A8A))
                }
                .buttonStyle(.plain)
                .help("Open Alfred's help for this page")
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 78)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xD9D9D9))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.10)).frame(height: 1)
        }
    }
}

/// Flat preferences canvas. Alfred does not use translucency here.
struct PageSurface<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(hex: 0xECECEC))
    }
}

/// Big white rounded content panel used under the page header.
struct FormPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        content()
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Color.white))
            .overlay(shape.stroke(Color.black.opacity(0.07), lineWidth: 1))
    }
}
