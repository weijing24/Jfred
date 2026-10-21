import JlfredCore
import SwiftUI

enum JlfredColor {
    static let sidebar = Color(hex: 0x561D7E)
    static let sidebarSelected = Color(hex: 0x330D4E)
    static let canvas = Color(hex: 0xF2F2F2)
    static let ink = Color(hex: 0x2C2C2C)
    static let sub = Color(hex: 0x6E6E6E)
    static let hotkey = Color(hex: 0x8E2BB8)
    static let line = Color.black.opacity(0.14)
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

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let fontName {
            return .custom(fontName, size: size)
        }
        return .system(size: size, weight: weight)
    }

    static let all: [LauncherTheme] = [
        LauncherTheme(id: "jlfred", name: "Jlfred", detail: "Jlfred Default Theme", query: Color(hex: 0x222222), title: .black, subtitle: Color(hex: 0x6A6A6A), selected: Color(hex: 0x561D7E), selectedTitle: .white, selectedSubtitle: Color.white.opacity(0.82), background: Color(hex: 0xF7F7F7), material: nil, radius: 10, querySize: 42, fontName: nil),
        LauncherTheme(id: "jlfred-dark", name: "Jlfred Dark", detail: "Jlfred Default Theme", query: .white, title: .white, subtitle: Color.white.opacity(0.62), selected: Color(hex: 0x6D28A8), selectedTitle: .white, selectedSubtitle: Color.white.opacity(0.8), background: Color(hex: 0x1C1C1E), material: nil, radius: 10, querySize: 42, fontName: nil),
        LauncherTheme(id: "modern", name: "Jlfred Modern", detail: "Jlfred Default Theme", query: Color(hex: 0x1C1C1E), title: Color(hex: 0x1C1C1E), subtitle: Color(hex: 0x6E6E73), selected: Color(hex: 0x581672), selectedTitle: .white, selectedSubtitle: Color.white.opacity(0.84), background: Color.white.opacity(0.72), material: .ultraThin, radius: 16, querySize: 48, fontName: nil),
        LauncherTheme(id: "modern-dark", name: "Jlfred Modern Dark", detail: "Jlfred Default Theme", query: .white, title: .white, subtitle: Color.white.opacity(0.66), selected: Color(hex: 0x6B21A8), selectedTitle: .white, selectedSubtitle: Color.white.opacity(0.84), background: Color.black.opacity(0.45), material: .ultraThin, radius: 16, querySize: 48, fontName: nil),
        LauncherTheme(id: "classic", name: "Jlfred Classic", detail: "Jlfred Default Theme", query: .white, title: .white, subtitle: Color.white.opacity(0.7), selected: Color(hex: 0xE6E6E6), selectedTitle: .black, selectedSubtitle: Color.black.opacity(0.6), background: Color(hex: 0x2A2A2A), material: nil, radius: 8, querySize: 34, fontName: nil),
        LauncherTheme(id: "macos", name: "Jlfred macOS", detail: "Jlfred Default Theme", query: .primary, title: .primary, subtitle: .secondary, selected: Color.accentColor, selectedTitle: .white, selectedSubtitle: Color.white.opacity(0.85), background: Color.white.opacity(0.55), material: .regular, radius: 12, querySize: 36, fontName: nil),
        LauncherTheme(id: "macos-dark", name: "Jlfred macOS Dark", detail: "Jlfred Default Theme", query: .white, title: .white, subtitle: Color.white.opacity(0.65), selected: Color.accentColor, selectedTitle: .white, selectedSubtitle: Color.white.opacity(0.85), background: Color.black.opacity(0.45), material: .regular, radius: 12, querySize: 36, fontName: nil),
        LauncherTheme(id: "frosty", name: "Frosty Teal", detail: "Jlfred Default Theme", query: Color(hex: 0x12343A), title: Color(hex: 0x12343A), subtitle: Color(hex: 0x4C7076), selected: Color(hex: 0x128E8E), selectedTitle: .white, selectedSubtitle: Color.white.opacity(0.85), background: Color(hex: 0xF3FBFA), material: nil, radius: 14, querySize: 42, fontName: nil),
        LauncherTheme(id: "avenir", name: "Large Avenir", detail: "Jlfred Default Theme", query: Color(hex: 0x222222), title: Color(hex: 0x222222), subtitle: Color(hex: 0x666666), selected: Color(hex: 0x333333), selectedTitle: .white, selectedSubtitle: Color.white.opacity(0.75), background: .white, material: nil, radius: 6, querySize: 54, fontName: "Avenir Next"),
        LauncherTheme(id: "contrast", name: "High Contrast Light", detail: "Jlfred Default Theme", query: .black, title: .black, subtitle: .black, selected: Color(hex: 0xFFE14A), selectedTitle: .black, selectedSubtitle: .black, background: .white, material: nil, radius: 4, querySize: 46, fontName: nil),
    ]

    static func by(id: String) -> LauncherTheme {
        all.first { $0.id == id } ?? all[2]
    }
}

struct BowlerHat: View {
    var showsGlass: Bool = true
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Ellipse()
                    .fill(Color(white: 0.12))
                    .frame(width: w * 0.92, height: h * 0.22)
                    .offset(y: h * 0.30)
                Capsule()
                    .fill(Color(white: 0.08))
                    .frame(width: w * 0.58, height: h * 0.46)
                    .offset(y: -h * 0.06)
                RoundedRectangle(cornerRadius: 3)
                    .fill(JlfredColor.sidebar)
                    .frame(width: w * 0.62, height: h * 0.09)
                    .offset(y: h * 0.05)
                if showsGlass {
                    Circle()
                        .stroke(Color.white.opacity(0.95), lineWidth: max(1, w * 0.045))
                        .background(Circle().fill(Color.white.opacity(0.18)))
                        .frame(width: w * 0.34, height: w * 0.34)
                        .offset(x: w * 0.16, y: -h * 0.22)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(white: 0.45))
                        .frame(width: max(2, w * 0.045), height: h * 0.24)
                        .rotationEffect(.degrees(38))
                        .offset(x: w * 0.01, y: h * 0.02)
                }
            }
            .frame(width: w, height: h)
        }
    }
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
                .foregroundStyle(JlfredColor.ink)
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
            .foregroundStyle(JlfredColor.sub)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 142)
    }
}

struct WindowReader: NSViewRepresentable {
    var onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window { onResolve(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
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
                .foregroundStyle(prominent ? JlfredColor.hotkey : Color.primary)
        }
        .font(.system(size: 15))
        .foregroundStyle(Color.secondary)
    }
}

struct HotkeyCapture: NSViewRepresentable {
    var onSet: (UInt16, UInt) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onSet = onSet
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.onSet = onSet
    }
}

final class RecorderView: NSView {
    var onSet: ((UInt16, UInt) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        onSet?(event.keyCode, flags.rawValue)
        window?.makeFirstResponder(nil)
    }
    override func drawFocusRingMask() { bounds.fill() }
    override var focusRingMaskBounds: NSRect { bounds }
}

struct ResultIcon: View {
    var icon: String
    var tint: Color = .primary
    var body: some View {
        Group {
            if icon.hasPrefix("file:") {
                AppIcon(path: String(icon.dropFirst("file:".count)))
            } else if icon.hasPrefix("symbol:") {
                Image(systemName: String(icon.dropFirst("symbol:".count)))
                    .font(.system(size: 22))
                    .foregroundStyle(tint)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 32, height: 32)
    }
}

struct AppIcon: NSViewRepresentable {
    var path: String
    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        // Workspace icons report a large intrinsic size. Let SwiftUI's frame win.
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.image = image
        return view
    }
    func updateNSView(_ nsView: NSImageView, context: Context) { nsView.image = image }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSImageView, context: Context) -> CGSize? {
        CGSize(width: 32, height: 32)
    }
    private var image: NSImage {
        if path.isEmpty { return NSWorkspace.shared.icon(for: .folder) }
        return NSWorkspace.shared.icon(forFile: path)
    }
}

func menuHatImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
        NSColor.black.setFill()
        let brim = NSBezierPath(ovalIn: NSRect(x: 1, y: 3, width: 16, height: 5))
        brim.fill()
        let crown = NSBezierPath(roundedRect: NSRect(x: 4, y: 6, width: 10, height: 8), xRadius: 4, yRadius: 4)
        crown.fill()
        return true
    }
    image.isTemplate = true
    return image
}
