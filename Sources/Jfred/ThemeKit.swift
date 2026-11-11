import AppKit
import ImageIO
import JfredCore
import SwiftUI
import UniformTypeIdentifiers

enum JfredColor {
    /// Legacy purple rail, kept for any remaining deep lists.
    static let sidebar = Color(hex: 0x4F217A)
    static let sidebarDeep = Color(hex: 0x2F104B)
    static let sidebarSelected = Color(hex: 0x3A1465)
    static let sidebarRowSelected = Color(hex: 0x583F70)
    static let canvas = Color(hex: 0xF3F3F5)
    static let prefsRail = Color(hex: 0xE8E8ED)
    static let ink = Color(hex: 0x1D1D1F)
    static let sub = Color(hex: 0x6E6E73)
    static let hotkey = Color(hex: 0x8E2BB8)
    static let line = Color.black.opacity(0.10)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

struct LauncherTheme: Identifiable {
    var id: String
    var name: String
    var detail: String
    var query: Color
    var title: Color
    var subtitle: Color
    var selected: Color
    var selectedTitle: Color
    var selectedSubtitle: Color
    var background: Color
    var material: Material?
    var radius: CGFloat
    var querySize: CGFloat
    var fontName: String?
    var width: CGFloat = 559
    var paddingH: CGFloat = 9
    var paddingV: CGFloat = 8
    var iconSize: CGFloat = 40
    var iconPadding: CGFloat = 4
    var rowPaddingV: CGFloat = 3
    var textSpacing: CGFloat = 5
    var resultTextSize: CGFloat = 18
    var resultSubtextSize: CGFloat = 12
    var shortcutSize: CGFloat = 16
    var searchBackground: Color = Color.black.opacity(0.10)
    var searchSelected: Color = Color(hex: 0x480069)
    var border: Color = Color.black.opacity(0.50)
    var blur: Double = 15
    var searchWeight: Font.Weight = .regular
    var usesGlass: Bool = false
    var highlightRadius: CGFloat? = nil
    var searchFieldRadius: CGFloat? = nil

    var rowHighlightRadius: CGFloat { highlightRadius ?? min(max(radius, 4), 8) }
    var fieldRadius: CGFloat { searchFieldRadius ?? min(max(radius, 4), 8) }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let fontName {
            return .custom(fontName, size: size)
        }
        return .system(size: size, weight: weight)
    }

    var queryFont: Font { font(size: querySize, weight: searchWeight) }

    var queryNSFont: NSFont {
        if let fontName, let custom = NSFont(name: fontName, size: querySize) { return custom }
        return NSFont.systemFont(ofSize: querySize, weight: searchWeight == .light ? .light : .regular)
    }

    /// A result row is laid out as max(icon, text block) + vertical padding.
    var rowHeight: CGFloat {
        max(iconSize, resultTextSize + textSpacing + resultSubtextSize) + rowPaddingV * 2 + 4
    }

    var queryBoxHeight: CGFloat { querySize + 16 }

    init(id: String, name: String, detail: String, query: Color, title: Color, subtitle: Color, selected: Color, selectedTitle: Color, selectedSubtitle: Color, background: Color, material: Material?, radius: CGFloat, querySize: CGFloat, fontName: String?, width: CGFloat = 559, paddingH: CGFloat = 9, paddingV: CGFloat = 8, iconSize: CGFloat = 40, iconPadding: CGFloat = 4, rowPaddingV: CGFloat = 3, textSpacing: CGFloat = 5, resultTextSize: CGFloat = 18, resultSubtextSize: CGFloat = 12, shortcutSize: CGFloat = 16, searchBackground: Color = Color.black.opacity(0.10), searchSelected: Color = Color(hex: 0x480069), border: Color = Color.black.opacity(0.50), blur: Double = 15, searchWeight: Font.Weight = .regular, usesGlass: Bool = false, highlightRadius: CGFloat? = nil, searchFieldRadius: CGFloat? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
        self.query = query
        self.title = title
        self.subtitle = subtitle
        self.selected = selected
        self.selectedTitle = selectedTitle
        self.selectedSubtitle = selectedSubtitle
        self.background = background
        self.material = material
        self.radius = radius
        self.querySize = querySize
        self.fontName = fontName
        self.width = width
        self.paddingH = paddingH
        self.paddingV = paddingV
        self.iconSize = iconSize
        self.iconPadding = iconPadding
        self.rowPaddingV = rowPaddingV
        self.textSpacing = textSpacing
        self.resultTextSize = resultTextSize
        self.resultSubtextSize = resultSubtextSize
        self.shortcutSize = shortcutSize
        self.searchBackground = searchBackground
        self.searchSelected = searchSelected
        self.border = border
        self.blur = blur
        self.searchWeight = searchWeight
        self.usesGlass = usesGlass
        self.highlightRadius = highlightRadius
        self.searchFieldRadius = searchFieldRadius
    }

    init(custom: CustomTheme) {
        func clamp(_ value: Double, _ low: Double, _ high: Double) -> CGFloat {
            CGFloat(min(max(value, low), high))
        }
        self.init(
            id: custom.id,
            name: custom.name,
            detail: "Custom Theme",
            query: Color(hexString: custom.query),
            title: Color(hexString: custom.title),
            subtitle: Color(hexString: custom.subtitle),
            selected: Color(hexString: custom.selected),
            selectedTitle: Color(hexString: custom.selectedTitle),
            selectedSubtitle: Color(hexString: custom.selectedSubtitle),
            background: Color(hexString: custom.background),
            material: nil,
            radius: clamp(custom.radius, 0, 30),
            querySize: clamp(custom.querySize, 12, 72),
            fontName: custom.fontName,
            width: clamp(custom.width, 320, 1200),
            paddingH: clamp(custom.paddingH, 0, 40),
            paddingV: clamp(custom.paddingV, 0, 40),
            iconSize: clamp(custom.iconSize, 16, 96),
            iconPadding: clamp(custom.iconPadding, 0, 30),
            rowPaddingV: clamp(custom.rowPaddingV, 0, 20),
            textSpacing: clamp(custom.textSpacing, 0, 20),
            resultTextSize: clamp(custom.resultTextSize, 10, 48),
            resultSubtextSize: clamp(custom.resultSubtextSize, 8, 32),
            shortcutSize: clamp(custom.shortcutSize, 8, 32),
            searchBackground: Color(hexString: custom.searchBackground),
            searchSelected: Color(hexString: custom.selected),
            border: Color(hexString: custom.border),
            blur: 0,
            searchWeight: .regular
        )
    }

    static let systemLight = LauncherTheme(
        id: "system-light", name: "Glassy Light", detail: "Built-in Theme",
        query: Color(rgba: 0x1D1D1FFF), title: Color(rgba: 0x1D1D1FF0), subtitle: Color(rgba: 0x3C3C4399),
        selected: Color(nsColor: .controlAccentColor), selectedTitle: .white, selectedSubtitle: Color.white.opacity(0.82),
        background: Color(rgba: 0xFFFFFFF0).opacity(0.58), material: .regular, radius: 26, querySize: 28,
        fontName: nil, width: 640, paddingH: 12, paddingV: 12, iconSize: 42,
        iconPadding: 8, rowPaddingV: 4, textSpacing: 3, resultTextSize: 17,
        resultSubtextSize: 12, shortcutSize: 13, searchBackground: Color.black.opacity(0.06),
        searchSelected: Color(nsColor: .controlAccentColor), border: Color.white.opacity(0.42), blur: 28,
        searchWeight: .regular, usesGlass: true, highlightRadius: 10, searchFieldRadius: 12
    )

    static let systemDark = LauncherTheme(
        id: "system-dark", name: "Glassy Dark", detail: "Built-in Theme",
        query: Color(rgba: 0xF5F5F7FF), title: Color(rgba: 0xF5F5F7F0), subtitle: Color(rgba: 0xEBEBF599),
        selected: Color(nsColor: .controlAccentColor), selectedTitle: .white, selectedSubtitle: Color.white.opacity(0.82),
        background: Color(rgba: 0x1C1C1EF0).opacity(0.52), material: .regular, radius: 26, querySize: 28,
        fontName: nil, width: 640, paddingH: 12, paddingV: 12, iconSize: 42,
        iconPadding: 8, rowPaddingV: 4, textSpacing: 3, resultTextSize: 17,
        resultSubtextSize: 12, shortcutSize: 13, searchBackground: Color.white.opacity(0.08),
        searchSelected: Color(nsColor: .controlAccentColor), border: Color.white.opacity(0.22), blur: 28,
        searchWeight: .regular, usesGlass: true, highlightRadius: 10, searchFieldRadius: 12
    )

    static let systemFlatLight = LauncherTheme(
        id: "system-flat-light", name: "Flat Light", detail: "Built-in Theme",
        query: Color(rgba: 0x1D1D1FFF), title: Color(rgba: 0x1D1D1FF0), subtitle: Color(rgba: 0x3C3C4399),
        selected: Color(nsColor: .controlAccentColor), selectedTitle: .white, selectedSubtitle: Color.white.opacity(0.82),
        background: Color(rgba: 0xF5F5F7F5), material: nil, radius: 26, querySize: 28,
        fontName: nil, width: 640, paddingH: 12, paddingV: 12, iconSize: 42,
        iconPadding: 8, rowPaddingV: 4, textSpacing: 3, resultTextSize: 17,
        resultSubtextSize: 12, shortcutSize: 13, searchBackground: Color.black.opacity(0.06),
        searchSelected: Color(nsColor: .controlAccentColor), border: Color.black.opacity(0.10), blur: 0,
        searchWeight: .regular, usesGlass: false, highlightRadius: 10, searchFieldRadius: 12
    )

    static let systemFlatDark = LauncherTheme(
        id: "system-flat-dark", name: "Flat Dark", detail: "Built-in Theme",
        query: Color(rgba: 0xF5F5F7FF), title: Color(rgba: 0xF5F5F7F0), subtitle: Color(rgba: 0xEBEBF599),
        selected: Color(nsColor: .controlAccentColor), selectedTitle: .white, selectedSubtitle: Color.white.opacity(0.82),
        background: Color(rgba: 0x1C1C1EF5), material: nil, radius: 26, querySize: 28,
        fontName: nil, width: 640, paddingH: 12, paddingV: 12, iconSize: 42,
        iconPadding: 8, rowPaddingV: 4, textSpacing: 3, resultTextSize: 17,
        resultSubtextSize: 12, shortcutSize: 13, searchBackground: Color.white.opacity(0.08),
        searchSelected: Color(nsColor: .controlAccentColor), border: Color.white.opacity(0.12), blur: 0,
        searchWeight: .regular, usesGlass: false, highlightRadius: 10, searchFieldRadius: 12
    )

    /// Picker entry for the auto appearance theme. `by(id:)` resolves the colours.
    static let systemAuto = LauncherTheme(
        id: "system", name: "System", detail: "Follows light and dark appearance",
        query: Color(rgba: 0x1D1D1FFF), title: Color(rgba: 0x1D1D1FF0), subtitle: Color(rgba: 0x3C3C4399),
        selected: Color(nsColor: .controlAccentColor), selectedTitle: .white, selectedSubtitle: Color.white.opacity(0.82),
        background: Color(rgba: 0xFFFFFFF0).opacity(0.58), material: .regular, radius: 26, querySize: 28,
        fontName: nil, width: 640, paddingH: 12, paddingV: 12, iconSize: 42,
        iconPadding: 8, rowPaddingV: 4, textSpacing: 3, resultTextSize: 17,
        resultSubtextSize: 12, shortcutSize: 13, searchBackground: Color.black.opacity(0.06),
        searchSelected: Color(nsColor: .controlAccentColor), border: Color.white.opacity(0.42), blur: 28,
        searchWeight: .regular, usesGlass: true, highlightRadius: 10, searchFieldRadius: 12
    )

    static let all: [LauncherTheme] = [
        systemAuto, systemLight, systemDark, systemFlatLight, systemFlatDark,
        LauncherTheme(
            id: "alfred", name: "Classic Light", detail: "Built-in Theme",
            query: Color(rgba: 0x000000FF), title: Color(rgba: 0x000000E5), subtitle: Color(rgba: 0x00000065),
            selected: Color(rgba: 0x480069E4), selectedTitle: .white, selectedSubtitle: Color(rgba: 0xFFFFFFC4),
            background: Color(rgba: 0xFFFFFFDB), material: .regular, radius: 3, querySize: 34,
            fontName: nil, width: 559, paddingH: 9, paddingV: 8, iconSize: 40,
            iconPadding: 4, rowPaddingV: 3, textSpacing: 5, resultTextSize: 18,
            resultSubtextSize: 12, shortcutSize: 16, searchBackground: Color(rgba: 0x0000001A),
            searchSelected: Color(rgba: 0x480069E4), border: Color(rgba: 0x0000007F), blur: 15,
            searchWeight: .light
        ),
        LauncherTheme(
            id: "alfred-dark", name: "Classic Dark", detail: "Built-in Theme",
            query: .white, title: Color(rgba: 0xFFFFFFCB), subtitle: Color(rgba: 0xFFFFFF7E),
            selected: Color(rgba: 0x358188FF), selectedTitle: .white, selectedSubtitle: Color(rgba: 0xFFFFFFCB),
            background: Color(rgba: 0x000000C6), material: .regular, radius: 3, querySize: 34,
            fontName: nil, width: 559, paddingH: 9, paddingV: 8, iconSize: 40,
            iconPadding: 4, rowPaddingV: 3, textSpacing: 5, resultTextSize: 18,
            resultSubtextSize: 12, shortcutSize: 16, searchBackground: Color(rgba: 0x0000003E),
            searchSelected: Color(rgba: 0x358188FF), border: Color(rgba: 0x0000007F), blur: 15,
            searchWeight: .light
        ),
        LauncherTheme(
            id: "alfred-modern", name: "Modern Light", detail: "Built-in Theme",
            query: Color(rgba: 0x000000FF), title: Color(rgba: 0x000000E4), subtitle: Color(rgba: 0x00000098),
            selected: Color(rgba: 0x480069E4), selectedTitle: .white, selectedSubtitle: Color(rgba: 0xFFFFFFCB),
            background: Color(rgba: 0xF8F8F86B), material: nil, radius: 15, querySize: 36,
            fontName: nil, width: 700, paddingH: 9, paddingV: 9, iconSize: 40,
            iconPadding: 7, rowPaddingV: 3, textSpacing: 5, resultTextSize: 18,
            resultSubtextSize: 12, shortcutSize: 16, searchBackground: Color(rgba: 0x00000019),
            searchSelected: Color(rgba: 0x480069E4), border: Color(rgba: 0x0000007F), blur: 0,
            searchWeight: .light
        ),
        LauncherTheme(
            id: "alfred-modern-dark", name: "Modern Dark", detail: "Built-in Theme",
            query: .white, title: Color(rgba: 0xFFFFFFCB), subtitle: Color(rgba: 0xFFFFFF7E),
            selected: Color(rgba: 0x358188FF), selectedTitle: .white, selectedSubtitle: Color(rgba: 0xFFFFFFCB),
            background: Color(rgba: 0x00000066), material: nil, radius: 15, querySize: 36,
            fontName: nil, width: 700, paddingH: 9, paddingV: 9, iconSize: 40,
            iconPadding: 7, rowPaddingV: 3, textSpacing: 5, resultTextSize: 18,
            resultSubtextSize: 12, shortcutSize: 16, searchBackground: Color(rgba: 0x0000003E),
            searchSelected: Color(rgba: 0x358188FF), border: Color(rgba: 0x0000007F), blur: 0,
            searchWeight: .light
        ),
        LauncherTheme(
            id: "alfred-classic", name: "Classic Compact", detail: "Built-in Theme",
            query: Color(rgba: 0x000000FF), title: Color(rgba: 0x000000E5), subtitle: Color(rgba: 0x00000065),
            selected: Color(rgba: 0x480069E4), selectedTitle: .white, selectedSubtitle: Color(rgba: 0xFFFFFFC4),
            background: Color(rgba: 0xFFFFFFF2), material: nil, radius: 3, querySize: 30,
            fontName: nil, width: 559, paddingH: 9, paddingV: 8, iconSize: 38,
            iconPadding: 4, rowPaddingV: 3, textSpacing: 5, resultTextSize: 17,
            resultSubtextSize: 12, shortcutSize: 15, searchBackground: Color(rgba: 0x0000001A),
            searchSelected: Color(rgba: 0x480069E4), border: Color(rgba: 0x0000007F), blur: 15,
            searchWeight: .regular
        ),
        LauncherTheme(
            id: "alfred-macos", name: "macOS Light", detail: "Built-in Theme",
            query: Color(rgba: 0x000000FF), title: Color(rgba: 0x000000E5), subtitle: Color(rgba: 0x00000065),
            selected: Color(rgba: 0x016BDEFF), selectedTitle: .white, selectedSubtitle: Color(rgba: 0xFFFFFFC4),
            background: Color(rgba: 0xFFFFFFE5), material: .regular, radius: 3, querySize: 34,
            fontName: nil, width: 559, paddingH: 0, paddingV: 4, iconSize: 40,
            iconPadding: 4, rowPaddingV: 3, textSpacing: 5, resultTextSize: 18,
            resultSubtextSize: 12, shortcutSize: 16, searchBackground: Color.clear,
            searchSelected: Color(rgba: 0x016BDEFF), border: Color(rgba: 0x0000007F), blur: 10,
            searchWeight: .light
        ),
        LauncherTheme(
            id: "alfred-macos-dark", name: "macOS Dark", detail: "Built-in Theme",
            query: .white, title: Color(rgba: 0xFFFFFFD8), subtitle: Color(rgba: 0xFFFFFF66),
            selected: Color(rgba: 0x016BDEFF), selectedTitle: .white, selectedSubtitle: Color(rgba: 0xFFFFFFCC),
            background: Color(rgba: 0x000000D8), material: .regular, radius: 3, querySize: 34,
            fontName: nil, width: 559, paddingH: 0, paddingV: 4, iconSize: 40,
            iconPadding: 4, rowPaddingV: 3, textSpacing: 5, resultTextSize: 18,
            resultSubtextSize: 12, shortcutSize: 16, searchBackground: Color.clear,
            searchSelected: Color(rgba: 0x016BDEFF), border: Color(rgba: 0x0000007F), blur: 15,
            searchWeight: .light
        ),
        LauncherTheme(
            id: "frosty-teal", name: "Frosty Teal", detail: "Built-in Theme",
            query: .white, title: Color(rgba: 0xFFFFFFAD), subtitle: Color(rgba: 0xFFFFFF6F),
            selected: Color(rgba: 0x0000001F), selectedTitle: .white, selectedSubtitle: Color(rgba: 0xFFFFFFA7),
            background: Color(rgba: 0x106480B4), material: .regular, radius: 3, querySize: 40,
            fontName: nil, width: 573, paddingH: 0, paddingV: 5, iconSize: 44,
            iconPadding: 6, rowPaddingV: 4, textSpacing: 7, resultTextSize: 21,
            resultSubtextSize: 12, shortcutSize: 15, searchBackground: Color.clear,
            searchSelected: Color(rgba: 0x00000055), border: .black, blur: 20,
            searchWeight: .light
        ),
        LauncherTheme(
            id: "large-avenir", name: "Large Avenir", detail: "Built-in Theme",
            query: .white, title: Color(rgba: 0xFFFFFFDB), subtitle: Color(rgba: 0xFFFFFF7F),
            selected: Color(rgba: 0x1D6488FF), selectedTitle: Color(rgba: 0xFFFFFFE8), selectedSubtitle: Color(rgba: 0xFFFFFFCB),
            background: Color(rgba: 0x272727F1), material: .regular, radius: 5, querySize: 46,
            fontName: "Avenir", width: 683, paddingH: 0, paddingV: 5, iconSize: 47,
            iconPadding: 11, rowPaddingV: 7, textSpacing: 6, resultTextSize: 26,
            resultSubtextSize: 14, shortcutSize: 20, searchBackground: Color.clear,
            searchSelected: Color(rgba: 0x144863FF), border: Color(rgba: 0x0000003F), blur: 15,
            searchWeight: .regular
        ),
        LauncherTheme(
            id: "high-contrast", name: "High Contrast Light", detail: "Built-in Theme",
            query: .black, title: Color(rgba: 0x000000E5), subtitle: Color(rgba: 0x000000B6),
            selected: Color(rgba: 0x000000DA), selectedTitle: .white, selectedSubtitle: Color(rgba: 0xFFFFFFD9),
            background: Color(rgba: 0xFFFFFFFF), material: nil, radius: 2, querySize: 38,
            fontName: "Avenir", width: 559, paddingH: 12, paddingV: 10, iconSize: 45,
            iconPadding: 4, rowPaddingV: 5, textSpacing: 7, resultTextSize: 24,
            resultSubtextSize: 14, shortcutSize: 17, searchBackground: Color(rgba: 0xCBCBCBF3),
            searchSelected: Color(rgba: 0xFFFFFF93), border: Color(rgba: 0x0000007F), blur: 15,
            searchWeight: .regular
        ),
    ]

    @MainActor static func isDarkAppearance(_ scheme: ColorScheme? = nil) -> Bool {
        if let scheme { return scheme == .dark }
        return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// Resolves a stored theme id. `"system"` and `"default"` follow the
    /// current appearance. A stored `"alfred"` id is left as the classic theme.
    @MainActor static func by(id: String, custom: [CustomTheme] = [], colorScheme: ColorScheme? = nil) -> LauncherTheme {
        if let custom = custom.first(where: { $0.id == id }) {
            return LauncherTheme(custom: custom)
        }
        if id == "system" || id == "default" {
            return isDarkAppearance(colorScheme) ? systemDark : systemLight
        }
        let legacy = [
            "jfred": "alfred", "jfred-dark": "alfred-dark", "modern": "alfred-modern",
            "modern-dark": "alfred-modern-dark", "classic": "alfred-classic",
            "macos": "alfred-macos", "macos-dark": "alfred-macos-dark",
            "frosty": "frosty-teal", "avenir": "large-avenir", "contrast": "high-contrast",
        ]
        let resolved = legacy[id] ?? id
        return all.first { $0.id == resolved } ?? systemLight
    }
}

extension Color {
    init(rgba: UInt32) {
        self.init(
            red: Double((rgba >> 24) & 0xFF) / 255,
            green: Double((rgba >> 16) & 0xFF) / 255,
            blue: Double((rgba >> 8) & 0xFF) / 255,
            opacity: Double(rgba & 0xFF) / 255
        )
    }

    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        let value = UInt32(cleaned, radix: 16) ?? 0x000000FF
        self.init(rgba: cleaned.count >= 8 ? value : (value << 8 | 0xFF))
    }
}

struct HoodMark: View {
    var body: some View {
        Group {
            if let image = hoodLogoImage() {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                RedFedoraFallback()
            }
        }
        .clipShape(IconSquircle())
    }
}

/// macOS app-icon squircle. Corner radius is ~22.37% of the side.
struct IconSquircle: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let box = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        return RoundedRectangle(cornerRadius: side * 0.2237, style: .continuous).path(in: box)
    }
}

private struct RedFedoraFallback: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.78, green: 0.08, blue: 0.1))
                    .frame(width: w * 0.92, height: h * 0.28)
                    .offset(y: h * 0.22)
                Capsule()
                    .fill(Color(red: 0.86, green: 0.1, blue: 0.12))
                    .frame(width: w * 0.48, height: h * 0.42)
                    .offset(y: -h * 0.08)
                Capsule()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: w * 0.5, height: h * 0.08)
                    .offset(y: h * 0.02)
            }
            .frame(width: w, height: h)
        }
    }
}

func hoodLogoImage() -> NSImage? {
    for ext in ["png", "icns"] {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: ext),
              let image = NSImage(contentsOf: url) else { continue }
        return image
    }
    return nil
}

struct DamaskBackground: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 78
            var y: CGFloat = 0
            while y < size.height + step {
                var x: CGFloat = 0
                while x < size.width + step {
                    var path = Path()
                    path.addEllipse(in: CGRect(x: x + 8, y: y + 8, width: 34, height: 34))
                    path.addEllipse(in: CGRect(x: x + 18, y: y + 18, width: 18, height: 18))
                    context.stroke(path, with: .color(.black.opacity(0.035)), lineWidth: 1)
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

struct WallpaperArt: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2E6BFF), Color(hex: 0x7A4DFF), Color(hex: 0xFF4F6D), Color(hex: 0xF2E24A), Color(hex: 0x7DDE2F)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color(hex: 0x3D7BFF).opacity(0.9)).frame(width: 520, height: 420).offset(x: 180, y: -220)
            Circle().fill(Color(hex: 0xFF5A6B).opacity(0.85)).frame(width: 480, height: 360).offset(x: -40, y: -40)
            Circle().fill(Color(hex: 0xC6F04A).opacity(0.9)).frame(width: 640, height: 420).offset(x: 40, y: 240)
            Circle().fill(Color(hex: 0x8A5CFF).opacity(0.55)).frame(width: 300, height: 300).blur(radius: 8).offset(x: 220, y: 20)
        }
    }
}

struct FormRow<Content: View>: View {
    var label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(JfredColor.ink)
                .frame(width: 128, alignment: .trailing)
            content()
            Spacer(minLength: 0)
        }
    }
}

struct HelpNote: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(JfredColor.sub)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 142)
    }
}

struct WindowReader: NSViewRepresentable {
    var onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ProbeView()
        view.onResolve = onResolve
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ProbeView)?.onResolve = onResolve
    }

    final class ProbeView: NSView {
        var onResolve: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            onResolve?(window)
            // SwiftUI applies the expanded preference toolbar after this view attaches.
            DispatchQueue.main.async { [weak window] in
                window?.toolbarStyle = .unified
                if #available(macOS 26.0, *) {
                    window?.styleMask.insert(.fullSizeContentView)
                    window?.titlebarAppearsTransparent = true
                    window?.titlebarSeparatorStyle = .none
                    window?.titleVisibility = .visible
                }
            }
        }
    }
}

func keyDisplayName(_ keyCode: UInt16) -> String {
    let special: [UInt16: String] = [
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
        76: "Enter", 115: "Home", 116: "Page Up", 119: "End", 121: "Page Down",
        123: "Left", 124: "Right", 125: "Down", 126: "Up",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
    if let name = special[keyCode] { return name }
    let ansi: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
    ]
    return ansi[keyCode] ?? "Key \(keyCode)"
}

struct HotkeyGlyphs: View {
    var hotkey: Hotkey
    var prominent = true
    var body: some View {
        HStack(spacing: 6) {
            if hotkey.modifiers & Hotkey.control != 0 { Text("⌃") }
            if hotkey.modifiers & Hotkey.option != 0 { Text("⌥") }
            if hotkey.modifiers & Hotkey.shift != 0 { Text("⇧") }
            if hotkey.modifiers & Hotkey.command != 0 { Text("⌘") }
            Text(keyDisplayName(hotkey.keyCode))
                .font(.system(size: prominent ? 18 : 13, weight: .semibold))
                .foregroundStyle(prominent ? JfredColor.hotkey : Color.primary)
        }
        .font(.system(size: 15))
        .foregroundStyle(Color.secondary)
    }
}

struct HotkeyCapture: NSViewRepresentable {
    var onSet: (UInt16, UInt) -> Void
    var onFocus: (Bool) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onSet = onSet
        view.onFocus = onFocus
        view.focusRingType = .none
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.onSet = onSet
        nsView.onFocus = onFocus
    }
}

final class RecorderView: NSView {
    var onSet: ((UInt16, UInt) -> Void)?
    var onFocus: ((Bool) -> Void)?
    private var monitor: Any?
    private var finishing = false
    /// Stays false until a click, so opening General does not start capture.
    private var capturing = false
    private static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    override var acceptsFirstResponder: Bool { capturing }

    override func mouseDown(with event: NSEvent) {
        capturing = true
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        installMonitor()
        onFocus?(true)
        return true
    }

    override func resignFirstResponder() -> Bool {
        capturing = false
        removeMonitor()
        onFocus?(false)
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        _ = capture(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return false }
        return capture(event)
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window?.firstResponder === self else { return event }
            return self.capture(event) ? nil : event
        }
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func capture(_ event: NSEvent) -> Bool {
        if finishing { return true }
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return true
        }
        if Self.modifierKeyCodes.contains(event.keyCode) { return true }
        finishing = true
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        onSet?(event.keyCode, flags.rawValue)
        window?.makeFirstResponder(nil)
        finishing = false
        return true
    }
}

struct ResultIcon: View {
    var icon: String
    var tint: Color = .primary
    var size: CGFloat = 40
    var body: some View {
        Group {
            if icon.hasPrefix("clipimage:") {
                AppIcon(path: String(icon.dropFirst("clipimage:".count)), preview: true, side: size)
            } else if icon.hasPrefix("image:") {
                AppIcon(path: String(icon.dropFirst("image:".count)), artwork: true, side: size)
            } else if icon.hasPrefix("file:") {
                AppIcon(path: String(icon.dropFirst("file:".count)), side: size)
            } else if icon.hasPrefix("filetype:") {
                AppIcon(path: String(icon.dropFirst("filetype:".count)), fileType: true, side: size)
            } else if icon.hasPrefix("symbol:") {
                Image(systemName: String(icon.dropFirst("symbol:".count)))
                    .font(.system(size: size * 0.62))
                    .foregroundStyle(tint)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: size * 0.62))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Result-row icons. Icons are drawn off the main thread at twice the row icon
/// size and kept in a bounded LRU; a row shows a generic placeholder until its
/// icon arrives.
@MainActor
final class IconCache {
    static let shared = IconCache()

    /// Every entry is an 80 x 80 px bitmap (25.6 KB). 768 entries hold every
    /// indexed app (about 175 on the owner's Mac), a full clipboard history of
    /// image thumbnails (250 clips) and a few hundred file icons, about 20 MB
    /// when full. The cost limit only matters if an entry were larger.
    static let countLimit = 768
    static let costLimit = 24 * 1024 * 1024

    enum Style: Sendable, Hashable {
        /// The Finder icon of a file, folder or app.
        case file
        /// A thumbnail of an image file, for clipboard images.
        case preview
        /// An image file shown as itself, for workflow icons.
        case artwork
        /// The icon of a file type: a UTI or a file name extension.
        case fileType
    }

    struct Request: Sendable, Hashable {
        var path: String
        var style: Style

        /// Parses a `SearchResult` icon string; nil for symbols and other icons
        /// that need no drawing.
        init?(icon: String) {
            let prefixes: [(String, Style)] = [("file:", .file), ("clipimage:", .preview), ("image:", .artwork), ("filetype:", .fileType)]
            for (prefix, style) in prefixes where icon.hasPrefix(prefix) {
                self.init(path: String(icon.dropFirst(prefix.count)), style: style)
                return
            }
            return nil
        }

        init(path: String, style: Style) {
            self.path = path
            self.style = style
        }

        var key: String {
            switch style {
            case .file: return path
            case .preview: return "preview:\(path)"
            case .artwork: return "image:\(path)"
            case .fileType: return "filetype:\(path)"
            }
        }
    }

    /// A drawn icon handed from the render queue to the main thread. The
    /// bitmap is immutable once drawn.
    private struct Rendered: @unchecked Sendable {
        var image: CGImage
        var size: NSSize
    }

    private let images = LRUCache<String, NSImage>(countLimit: IconCache.countLimit, costLimit: IconCache.costLimit)
    private var operations: [String: Operation] = [:]
    private var waiting: [String: [(NSImage) -> Void]] = [:]
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "dev.jim.jfred.icons"
        // Icon Services serializes most of the work; more threads only contend.
        queue.maxConcurrentOperationCount = 2
        queue.qualityOfService = .userInitiated
        return queue
    }()
    nonisolated private static let side: CGFloat = 40
    private var placeholders: [String: NSImage] = [:]

    /// The icon if it is cached. Otherwise starts drawing it, unless that has
    /// already started, and returns nil; `completion` then runs on the main
    /// thread with the icon.
    func image(for request: Request, priority: Operation.QueuePriority = .high, completion: ((NSImage) -> Void)? = nil) -> NSImage? {
        let key = request.key
        if let cached = images.value(for: key) { return cached }
        if let completion { waiting[key, default: []].append(completion) }
        if let operation = operations[key] {
            if priority.rawValue > operation.queuePriority.rawValue, !operation.isExecuting {
                operation.queuePriority = priority
            }
            return nil
        }
        let operation = BlockOperation {
            let rendered = IconCache.render(request)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    IconCache.shared.finish(request, rendered)
                }
            }
        }
        operation.queuePriority = priority
        operations[key] = operation
        queue.addOperation(operation)
        return nil
    }

    /// Draws icons before rows ask for them.
    func prefetch(_ requests: [Request], priority: Operation.QueuePriority = .normal) {
        for request in requests where !images.contains(request.key) {
            _ = image(for: request, priority: priority)
        }
    }

    /// Keys prefetched for the result list on screen.
    private var resultKeys: Set<String> = []

    /// Prefetches icons for a new result list, visible rows first, and drops
    /// queued work for the previous list that has not started and that no row
    /// is waiting for, so fast typing does not queue icons nobody will see.
    func prefetchResults(visible: [Request], rest: [Request]) {
        let keys = Set((visible + rest).map(\.key))
        for key in resultKeys.subtracting(keys) {
            guard waiting[key] == nil, let operation = operations[key], !operation.isExecuting else { continue }
            operation.cancel()
            operations[key] = nil
        }
        resultKeys = keys
        prefetch(visible, priority: .high)
        prefetch(rest, priority: .normal)
    }

    /// A generic icon shown until the real one is drawn: an app, folder or
    /// document icon chosen from the path alone, without touching the disk.
    func placeholder(for request: Request) -> NSImage {
        let type: UTType
        switch request.style {
        case .file:
            let ext = (request.path as NSString).pathExtension.lowercased()
            if request.path.isEmpty || request.path.hasSuffix("/") || ext.isEmpty {
                type = .folder
            } else if ext == "app" {
                type = .application
            } else {
                type = .data
            }
        case .preview, .artwork:
            type = .image
        case .fileType:
            type = .data
        }
        if let cached = placeholders[type.identifier] { return cached }
        let image = NSWorkspace.shared.icon(for: type)
        placeholders[type.identifier] = image
        return image
    }

    private func finish(_ request: Request, _ rendered: Rendered?) {
        let key = request.key
        operations[key] = nil
        let image: NSImage
        if let rendered {
            image = NSImage(cgImage: rendered.image, size: rendered.size)
            images.setValue(image, for: key, cost: rendered.image.bytesPerRow * rendered.image.height)
        } else {
            // Drawing failed; keep the generic icon so the row does not retry.
            image = placeholder(for: request)
            images.setValue(image, for: key, cost: 0)
        }
        let completions = waiting.removeValue(forKey: key) ?? []
        for completion in completions { completion(image) }
    }

    // MARK: Drawing, on the render queue

    nonisolated private static func render(_ request: Request) -> Rendered? {
        let path = request.path
        switch request.style {
        case .preview:
            if let thumbnail = imageThumbnail(path) { return thumbnail }
            return draw(NSWorkspace.shared.icon(forFile: path))
        case .fileType:
            return draw(workspaceIcon(forFileType: path))
        case .artwork:
            if let artwork = artworkImage(at: path) { return draw(artwork) }
            return draw(NSWorkspace.shared.icon(forFile: path))
        case .file:
            return draw(path.isEmpty ? NSWorkspace.shared.icon(for: .folder) : NSWorkspace.shared.icon(forFile: path))
        }
    }

    nonisolated private static func workspaceIcon(forFileType value: String) -> NSImage {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let type = UTType(trimmed) { return NSWorkspace.shared.icon(for: type) }
        if let type = UTType(filenameExtension: trimmed) { return NSWorkspace.shared.icon(for: type) }
        return NSWorkspace.shared.icon(for: .data)
    }

    nonisolated private static func artworkImage(at path: String) -> NSImage? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return nil
        }
        if let image = NSImage(contentsOfFile: path), image.isValid,
           image.size.width > 0, image.size.height > 0, !image.representations.isEmpty {
            return image
        }
        return imageThumbnail(path).map { NSImage(cgImage: $0.image, size: $0.size) }
    }

    /// Draws `source` into a square bitmap twice the icon size, keeping its
    /// aspect ratio. A large image file is not kept at full size.
    nonisolated private static func draw(_ source: NSImage) -> Rendered? {
        let pixels = Int(side * 2)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        var rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        let size = source.size
        if size.width > 0, size.height > 0, size.width != size.height {
            let scale = min(rect.width / size.width, rect.height / size.height)
            let fitted = NSSize(width: size.width * scale, height: size.height * scale)
            rect = NSRect(x: (rect.width - fitted.width) / 2, y: (rect.height - fitted.height) / 2, width: fitted.width, height: fitted.height)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard let image = context.makeImage() else { return nil }
        return Rendered(image: image, size: NSSize(width: side, height: side))
    }

    nonisolated private static func imageThumbnail(_ path: String) -> Rendered? {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: side * 2,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        guard width > 0, height > 0 else { return nil }
        let scale = min(side / width, side / height)
        return Rendered(image: cg, size: NSSize(width: width * scale, height: height * scale))
    }
}

/// An image view that shows one `IconCache` request, with a placeholder until
/// the icon is drawn.
final class IconImageView: NSImageView {
    private var shownKey: String?

    func show(_ request: IconCache.Request) {
        guard request.key != shownKey else { return }
        let key = request.key
        shownKey = key
        let cached = IconCache.shared.image(for: request) { [weak self] image in
            guard let self, self.shownKey == key else { return }
            self.image = image
        }
        image = cached ?? IconCache.shared.placeholder(for: request)
    }
}

struct AppIcon: NSViewRepresentable {
    var path: String
    var preview: Bool = false
    var artwork: Bool = false
    var fileType: Bool = false
    var side: CGFloat = 40

    private var request: IconCache.Request {
        let style: IconCache.Style = preview ? .preview : fileType ? .fileType : artwork ? .artwork : .file
        return IconCache.Request(path: path, style: style)
    }

    func makeNSView(context: Context) -> IconImageView {
        let view = IconImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        view.imageFrameStyle = .none
        view.animates = false
        // Workspace icons report a large intrinsic size. Let SwiftUI's frame win.
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.show(request)
        return view
    }

    func updateNSView(_ nsView: IconImageView, context: Context) {
        nsView.show(request)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: IconImageView, context: Context) -> CGSize? {
        CGSize(width: side, height: side)
    }
}

func menuHatImage() -> NSImage {
    let side: CGFloat = 18
    let canvas = NSImage(size: NSSize(width: side, height: side))
    canvas.lockFocus()
    let radius = side * 0.2237
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: side, height: side), xRadius: radius, yRadius: radius).addClip()
    if let logo = hoodLogoImage() {
        logo.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
    } else {
        NSColor(calibratedRed: 0.82, green: 0.09, blue: 0.11, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 1, y: 3, width: 16, height: 6)).fill()
        NSBezierPath(roundedRect: NSRect(x: 4, y: 7, width: 10, height: 8), xRadius: 3, yRadius: 3).fill()
    }
    canvas.unlockFocus()
    canvas.isTemplate = false
    return canvas
}
