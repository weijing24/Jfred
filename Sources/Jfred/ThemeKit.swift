import AppKit
import JfredCore
import SwiftUI

enum JfredColor {
    /// Alfred-style two-level purple sidebar: a lighter rail, a deep list.
    static let sidebar = Color(hex: 0x4F217A)
    static let sidebarDeep = Color(hex: 0x2F104B)
    static let sidebarSelected = Color(hex: 0x3A1465)
    static let sidebarRowSelected = Color(hex: 0x583F70)
    static let canvas = Color(hex: 0xEDEDEC)
    static let ink = Color(hex: 0x303030)
    static let sub = Color(hex: 0x6E6E6E)
    static let hotkey = Color(hex: 0x8E2BB8)
    static let line = Color.black.opacity(0.12)
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

    /// Alfred lays a row out as max(icon, text block) + vertical padding.
    var rowHeight: CGFloat {
        max(iconSize, resultTextSize + textSpacing + resultSubtextSize) + rowPaddingV * 2 + 4
    }

    var queryBoxHeight: CGFloat { querySize + 16 }

    init(id: String, name: String, detail: String, query: Color, title: Color, subtitle: Color, selected: Color, selectedTitle: Color, selectedSubtitle: Color, background: Color, material: Material?, radius: CGFloat, querySize: CGFloat, fontName: String?, width: CGFloat = 559, paddingH: CGFloat = 9, paddingV: CGFloat = 8, iconSize: CGFloat = 40, iconPadding: CGFloat = 4, rowPaddingV: CGFloat = 3, textSpacing: CGFloat = 5, resultTextSize: CGFloat = 18, resultSubtextSize: CGFloat = 12, shortcutSize: CGFloat = 16, searchBackground: Color = Color.black.opacity(0.10), searchSelected: Color = Color(hex: 0x480069), border: Color = Color.black.opacity(0.50), blur: Double = 15, searchWeight: Font.Weight = .regular) {
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
    }

    init(custom: CustomTheme) {
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
            radius: CGFloat(custom.radius),
            querySize: CGFloat(custom.querySize),
            fontName: custom.fontName,
            width: CGFloat(custom.width),
            paddingH: CGFloat(custom.paddingH),
            paddingV: CGFloat(custom.paddingV),
            iconSize: CGFloat(custom.iconSize),
            iconPadding: CGFloat(custom.iconPadding),
            rowPaddingV: CGFloat(custom.rowPaddingV),
            textSpacing: CGFloat(custom.textSpacing),
            resultTextSize: CGFloat(custom.resultTextSize),
            resultSubtextSize: CGFloat(custom.resultSubtextSize),
            shortcutSize: CGFloat(custom.shortcutSize),
            searchBackground: Color(hexString: custom.searchBackground),
            searchSelected: Color(hexString: custom.selected),
            border: Color(hexString: custom.border),
            blur: 0,
            searchWeight: .regular
        )
    }

    static let all: [LauncherTheme] = [
        LauncherTheme(
            id: "alfred", name: "Alfred", detail: "Alfred Default Theme",
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
            id: "alfred-dark", name: "Alfred Dark", detail: "Alfred Default Theme",
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
            id: "alfred-modern", name: "Alfred Modern", detail: "Alfred Default Theme",
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
            id: "alfred-modern-dark", name: "Alfred Modern Dark", detail: "Alfred Default Theme",
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
            id: "alfred-classic", name: "Alfred Classic", detail: "Alfred Default Theme",
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
            id: "alfred-macos", name: "Alfred macOS", detail: "Alfred Default Theme",
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
            id: "alfred-macos-dark", name: "Alfred macOS Dark", detail: "Alfred Default Theme",
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
            id: "frosty-teal", name: "Frosty Teal", detail: "Alfred Default Theme",
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
            id: "large-avenir", name: "Large Avenir", detail: "Alfred Default Theme",
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
            id: "high-contrast", name: "High Contrast Light", detail: "Alfred Default Theme",
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

    static func by(id: String, custom: [CustomTheme] = []) -> LauncherTheme {
        if let custom = custom.first(where: { $0.id == id }) {
            return LauncherTheme(custom: custom)
        }
        let legacy = [
            "jfred": "alfred", "jfred-dark": "alfred-dark", "modern": "alfred-modern",
            "modern-dark": "alfred-modern-dark", "classic": "alfred-classic",
            "macos": "alfred-macos", "macos-dark": "alfred-macos-dark",
            "frosty": "frosty-teal", "avenir": "large-avenir", "contrast": "high-contrast",
        ]
        let resolved = legacy[id] ?? id
        return all.first { $0.id == resolved } ?? all[0]
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
                window?.toolbarStyle = .unifiedCompact
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
            if icon.hasPrefix("file:") {
                AppIcon(path: String(icon.dropFirst("file:".count)))
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

@MainActor
final class IconCache {
    static let shared = IconCache()
    private var images: [String: NSImage] = [:]
    private let side: CGFloat = 40

    func image(for path: String) -> NSImage {
        if let cached = images[path] { return cached }
        let rendered = render(path)
        images[path] = rendered
        return rendered
    }

    /// Draws icons ahead of the first search so rows do not appear empty.
    func prefetch(_ paths: [String]) {
        let missing = paths.filter { images[$0] == nil }
        guard !missing.isEmpty else { return }
        var index = 0
        func step() {
            let end = min(index + 20, missing.count)
            while index < end {
                images[missing[index]] = render(missing[index])
                index += 1
            }
            if index < missing.count {
                DispatchQueue.main.async(execute: step)
            }
        }
        DispatchQueue.main.async(execute: step)
    }

    private func render(_ path: String) -> NSImage {
        let source = path.isEmpty ? NSWorkspace.shared.icon(for: .folder) : NSWorkspace.shared.icon(forFile: path)
        var rect = NSRect(x: 0, y: 0, width: side * 2, height: side * 2)
        guard let cg = source.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            source.size = NSSize(width: side, height: side)
            return source
        }
        return NSImage(cgImage: cg, size: NSSize(width: side, height: side))
    }
}

struct AppIcon: NSViewRepresentable {
    var path: String
    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        view.imageFrameStyle = .none
        view.animates = false
        // Workspace icons report a large intrinsic size. Let SwiftUI's frame win.
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.image = IconCache.shared.image(for: path)
        return view
    }
    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = IconCache.shared.image(for: path)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSImageView, context: Context) -> CGSize? {
        CGSize(width: 40, height: 40)
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
