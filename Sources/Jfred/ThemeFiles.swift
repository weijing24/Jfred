import AppKit
import JfredCore
import SwiftUI

/// Reads and writes Alfred `.alfredappearance` files. Only the numeric and
/// colour fields that Jfred can render are imported; unknown keys are ignored.
enum ThemeFiles {
    static func read(_ url: URL) -> CustomTheme? {
        let converted = Shell.run("/usr/bin/plutil", ["-convert", "json", "-o", "-", url.path], timeout: 8)
        guard let data = converted.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let theme = root["alfredtheme"] as? [String: Any] else { return nil }
        let window = theme["window"] as? [String: Any] ?? [:]
        let search = theme["search"] as? [String: Any] ?? [:]
        let searchText = search["text"] as? [String: Any] ?? [:]
        let result = theme["result"] as? [String: Any] ?? [:]
        let text = result["text"] as? [String: Any] ?? [:]
        let subtext = result["subtext"] as? [String: Any] ?? [:]
        let shortcut = result["shortcut"] as? [String: Any] ?? [:]
        func number(_ dict: [String: Any], _ key: String, _ fallback: Double) -> Double {
            (dict[key] as? NSNumber)?.doubleValue ?? fallback
        }
        func string(_ dict: [String: Any], _ key: String, _ fallback: String) -> String {
            (dict[key] as? String) ?? fallback
        }
        let font = string(text, "font", "System")
        return CustomTheme(
            name: string(theme, "name", url.deletingPathExtension().lastPathComponent),
            width: number(window, "width", 559),
            radius: max(0, number(window, "roundness", 3)),
            paddingH: number(window, "paddingHorizontal", 9),
            paddingV: number(window, "paddingVertical", 8),
            querySize: number(searchText, "size", 34),
            resultTextSize: number(text, "size", 18),
            resultSubtextSize: number(subtext, "size", 12),
            shortcutSize: number(shortcut, "size", 16),
            iconSize: number(result, "iconSize", 40),
            iconPadding: number(result, "iconPaddingHorizontal", 4),
            rowPaddingV: number(result, "paddingVertical", 3),
            textSpacing: number(result, "textSpacing", 5),
            background: string(window, "color", "#FFFFFFDB"),
            query: string(searchText, "color", "#000000FF"),
            title: string(text, "color", "#000000E5"),
            subtitle: string(subtext, "color", "#00000065"),
            selected: string(result, "backgroundSelected", "#480069E4"),
            selectedTitle: string(text, "colorSelected", "#FFFFFFFF"),
            selectedSubtitle: string(subtext, "colorSelected", "#FFFFFFC4"),
            searchBackground: string(search, "background", "#0000001A"),
            border: string(window, "borderColor", "#0000007F"),
            fontName: font.contains("Avenir") ? "Avenir" : nil
        )
    }

    @discardableResult
    static func write(_ theme: LauncherTheme, to url: URL) -> Bool {
        let themeJSON: [String: Any] = [
            "name": theme.name,
            "window": [
                "width": Double(theme.width),
                "roundness": Double(theme.radius),
                "paddingHorizontal": Double(theme.paddingH),
                "paddingVertical": Double(theme.paddingV),
                "blur": theme.blur,
                "color": hex(theme.background),
                "borderColor": hex(theme.border),
                "borderPadding": 0,
            ],
            "search": [
                "background": hex(theme.searchBackground),
                "backgroundSelected": hex(theme.searchSelected),
                "paddingVertical": 5,
                "spacing": 8,
                "text": [
                    "size": Double(theme.querySize),
                    "font": theme.fontName == nil ? "System Light" : "Avenir",
                    "color": hex(theme.query),
                    "colorSelected": hex(theme.selectedTitle),
                ],
            ],
            "result": [
                "textSpacing": Double(theme.textSpacing),
                "iconSize": Double(theme.iconSize),
                "iconPaddingHorizontal": Double(theme.iconPadding),
                "paddingVertical": Double(theme.rowPaddingV),
                "backgroundSelected": hex(theme.selected),
                "text": [
                    "size": Double(theme.resultTextSize),
                    "font": theme.fontName == nil ? "System" : "Avenir",
                    "color": hex(theme.title),
                    "colorSelected": hex(theme.selectedTitle),
                ],
                "subtext": [
                    "size": Double(theme.resultSubtextSize),
                    "font": theme.fontName == nil ? "System" : "Avenir",
                    "color": hex(theme.subtitle),
                    "colorSelected": hex(theme.selectedSubtitle),
                ],
                "shortcut": [
                    "size": Double(theme.shortcutSize),
                    "font": theme.fontName == nil ? "System" : "Avenir",
                    "color": hex(theme.subtitle),
                    "colorSelected": hex(theme.selectedSubtitle),
                ],
            ],
            "separator": ["color": "#CBCBCBF3", "thickness": 0],
            "scrollbar": ["color": hex(theme.selected), "thickness": 2],
        ]
        let root: [String: Any] = ["alfredtheme": themeJSON]
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    private static func hex(_ color: Color) -> String {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        let a = Int((ns.alphaComponent * 255).rounded())
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
}
