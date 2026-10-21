import Foundation
import CryptoKit

public struct Conversion: Equatable, Sendable {
    public var text: String
    public var value: Double
    public init(text: String, value: Double) {
        self.text = text
        self.value = value
    }
}

public enum Units {
    public static func convert(_ raw: String) -> Conversion? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let arg = argument(of: "unit", in: text) { text = arg }
        let pattern = #"^\s*([0-9]*\.?[0-9]+)\s*([a-zA-Z]+)\s+(?:in|to|as)\s+([a-zA-Z]+)\s*$"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = expression.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text),
              let fromRange = Range(match.range(at: 2), in: text),
              let toRange = Range(match.range(at: 3), in: text),
              let value = Double(text[valueRange])
        else { return nil }
        let fromName = String(text[fromRange])
        let toName = String(text[toRange])
        guard let from = lookup(fromName), let to = lookup(toName), from.family == to.family else { return nil }
        let converted: Double
        if from.family == "temp" {
            converted = fromCelsius(toCelsius(value, unit: from), unit: to)
        } else {
            converted = value * from.factor / to.factor
        }
        guard converted.isFinite else { return nil }
        let formatted = Calculator.format(converted)
        return Conversion(text: "\(formatted) \(to.symbol)", value: converted)
    }

    private static func toCelsius(_ value: Double, unit: Unit) -> Double {
        switch unit.symbol {
        case "°F": return (value - 32) * 5 / 9
        case "K": return value - 273.15
        default: return value
        }
    }

    private static func fromCelsius(_ value: Double, unit: Unit) -> Double {
        switch unit.symbol {
        case "°F": return value * 9 / 5 + 32
        case "K": return value + 273.15
        default: return value
        }
    }

    private struct Unit {
        var family: String
        var symbol: String
        var factor: Double
    }

    private static func lookup(_ name: String) -> Unit? {
        switch name.lowercased() {
        case "mm", "millimeter", "millimeters": return Unit(family: "length", symbol: "mm", factor: 0.001)
        case "cm", "centimeter", "centimeters": return Unit(family: "length", symbol: "cm", factor: 0.01)
        case "m", "meter", "meters", "metre", "metres": return Unit(family: "length", symbol: "m", factor: 1)
        case "km", "kilometer", "kilometers", "kilometre", "kilometres": return Unit(family: "length", symbol: "km", factor: 1000)
        case "in", "inch", "inches": return Unit(family: "length", symbol: "in", factor: 0.0254)
        case "ft", "foot", "feet": return Unit(family: "length", symbol: "ft", factor: 0.3048)
        case "yd", "yard", "yards": return Unit(family: "length", symbol: "yd", factor: 0.9144)
        case "mi", "mile", "miles": return Unit(family: "length", symbol: "mi", factor: 1609.344)
        case "mg": return Unit(family: "mass", symbol: "mg", factor: 0.000001)
        case "g", "gram", "grams": return Unit(family: "mass", symbol: "g", factor: 0.001)
        case "kg", "kilogram", "kilograms": return Unit(family: "mass", symbol: "kg", factor: 1)
        case "oz", "ounce", "ounces": return Unit(family: "mass", symbol: "oz", factor: 0.028349523125)
        case "lb", "lbs", "pound", "pounds": return Unit(family: "mass", symbol: "lb", factor: 0.45359237)
        case "c", "celsius": return Unit(family: "temp", symbol: "°C", factor: 1)
        case "f", "fahrenheit": return Unit(family: "temp", symbol: "°F", factor: 1)
        case "k", "kelvin": return Unit(family: "temp", symbol: "K", factor: 1)
        case "s", "sec", "secs", "second", "seconds": return Unit(family: "time", symbol: "s", factor: 1)
        case "min", "mins", "minute", "minutes": return Unit(family: "time", symbol: "min", factor: 60)
        case "h", "hr", "hrs", "hour", "hours": return Unit(family: "time", symbol: "h", factor: 3600)
        case "d", "day", "days": return Unit(family: "time", symbol: "d", factor: 86400)
        case "b", "byte", "bytes": return Unit(family: "bytes", symbol: "B", factor: 1)
        case "kb", "kib": return Unit(family: "bytes", symbol: "KB", factor: 1024)
        case "mb", "mib": return Unit(family: "bytes", symbol: "MB", factor: 1024 * 1024)
        case "gb", "gib": return Unit(family: "bytes", symbol: "GB", factor: 1024 * 1024 * 1024)
        case "tb", "tib": return Unit(family: "bytes", symbol: "TB", factor: 1024 * 1024 * 1024 * 1024)
        case "mps": return Unit(family: "speed", symbol: "m/s", factor: 1)
        case "kph", "kmh": return Unit(family: "speed", symbol: "km/h", factor: 1 / 3.6)
        case "mph": return Unit(family: "speed", symbol: "mph", factor: 0.44704)
        default: return nil
        }
    }
}

public enum DevToys {
    public static func rows(argument: String) -> [(title: String, subtitle: String, payload: String)] {
        let arg = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        if arg.isEmpty || arg == "help" {
            return [
                ("UUID", "Copy a new UUID", UUID().uuidString),
                ("Timestamp", "Unix time", String(Int(Date().timeIntervalSince1970))),
                ("Base64 encode", "dev b64 text", ""),
                ("SHA256", "dev sha256 text", ""),
                ("JSON pretty", "dev json {…}", ""),
                ("URL encode", "dev url text", ""),
            ]
        }
        let parts = arg.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let command = String(parts.first ?? "").lowercased()
        let rest = parts.count > 1 ? String(parts[1]) : ""
        switch command {
        case "uuid":
            let value = UUID().uuidString
            return [("UUID", value, value)]
        case "time", "timestamp", "now":
            let value = String(Int(Date().timeIntervalSince1970))
            return [("Unix time", value, value)]
        case "b64", "base64":
            let value = Data(rest.utf8).base64EncodedString()
            return [("Base64", value, value)]
        case "b64d", "decode64":
            let value = Data(base64Encoded: rest).flatMap { String(data: $0, encoding: .utf8) } ?? "Not valid Base64"
            return [("Base64 decode", value, value)]
        case "sha256", "sha":
            let value = SHA256.hash(data: Data(rest.utf8)).map { String(format: "%02x", $0) }.joined()
            return [("SHA256", value, value)]
        case "sha1":
            let value = Insecure.SHA1.hash(data: Data(rest.utf8)).map { String(format: "%02x", $0) }.joined()
            return [("SHA1", value, value)]
        case "md5":
            let value = Insecure.MD5.hash(data: Data(rest.utf8)).map { String(format: "%02x", $0) }.joined()
            return [("MD5", value, value)]
        case "url", "urlencode":
            let value = rest.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rest
            return [("URL encode", value, value)]
        case "urldecode":
            let value = rest.removingPercentEncoding ?? rest
            return [("URL decode", value, value)]
        case "json":
            let value = prettyJSON(rest)
            return [("JSON", value, value)]
        default:
            return [("DevToys", "uuid, time, b64, sha256, md5, json, url", "")]
        }
    }

    private static func prettyJSON(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: pretty, encoding: .utf8)
        else { return "Not valid JSON" }
        return string
    }
}

public enum Epoch {
    public static func rows(argument: String, now: Date) -> [(title: String, subtitle: String, payload: String)] {
        let arg = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        let date: Date
        if arg.isEmpty || arg == "now" {
            date = now
        } else if let number = Double(arg), number > 1_000_000 {
            date = number > 10_000_000_000 ? Date(timeIntervalSince1970: number / 1000) : Date(timeIntervalSince1970: number)
        } else if let parsed = parseDate(arg) {
            date = parsed
        } else {
            return [("Epoch", "Type a unix time or a date", "")]
        }
        let seconds = String(Int(date.timeIntervalSince1970))
        let millis = String(Int(date.timeIntervalSince1970 * 1000))
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        let iso = ISO8601DateFormatter().string(from: date)
        return [
            (formatter.string(from: date), "Local time", iso),
            ("Unix \(seconds)", iso, seconds),
            ("Milliseconds \(millis)", "Unix milliseconds", millis),
        ]
    }

    private static func parseDate(_ text: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: text) { return date }
        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "yyyy/MM/dd"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}

public func argument(of keyword: String, in query: String) -> String? {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let folded = fold(trimmed)
    let key = fold(keyword)
    if folded == key { return "" }
    let prefix = key + " "
    if folded.hasPrefix(prefix) {
        return String(trimmed.dropFirst(prefix.count))
    }
    return nil
}

public struct SystemCommand: Sendable, Equatable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var symbol: String
    public var keywords: [String]
    public var category: String

    public init(id: String, title: String, subtitle: String, symbol: String, keywords: [String], category: String = "action") {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.keywords = keywords
        self.category = category
    }

    public static let all: [SystemCommand] = [
        SystemCommand(id: "sleep", title: "Sleep", subtitle: "Put this Mac to sleep", symbol: "moon.zzz", keywords: ["sleep"]),
        SystemCommand(id: "lock", title: "Lock Screen", subtitle: "Lock this Mac", symbol: "lock", keywords: ["lock", "lock screen"]),
        SystemCommand(id: "screensaver", title: "Screen Saver", subtitle: "Start the screen saver", symbol: "display", keywords: ["screensaver", "screen saver"]),
        SystemCommand(id: "restart", title: "Restart", subtitle: "Restart this Mac", symbol: "arrow.clockwise", keywords: ["restart", "reboot"]),
        SystemCommand(id: "shutdown", title: "Shut Down", subtitle: "Shut down this Mac", symbol: "power", keywords: ["shutdown", "shut down", "poweroff"]),
        SystemCommand(id: "logout", title: "Log Out", subtitle: "Log out of this account", symbol: "rectangle.portrait.and.arrow.right", keywords: ["logout", "log out"]),
        SystemCommand(id: "emptetrash", title: "Empty Trash", subtitle: "Empty the Finder trash", symbol: "trash", keywords: ["empty trash", "trash"]),
        SystemCommand(id: "eject", title: "Eject Disks", subtitle: "Eject removable disks", symbol: "eject", keywords: ["eject"]),
        SystemCommand(id: "quitall", title: "Quit All Apps", subtitle: "Quit every regular app", symbol: "xmark.circle", keywords: ["quit all", "quitall"]),
        SystemCommand(id: "darkmode", title: "Toggle Dark Mode", subtitle: "Switch appearance", symbol: "circle.lefthalf.filled", keywords: ["dark mode", "appearance"]),
        SystemCommand(id: "hidden", title: "Toggle Hidden Files", subtitle: "Show or hide invisible files in Finder", symbol: "eye", keywords: ["hidden files", "dotfiles"]),
        SystemCommand(id: "desktop", title: "Show Desktop", subtitle: "Reveal the desktop", symbol: "menubar.dock.rectangle", keywords: ["show desktop", "desktop"]),
        SystemCommand(id: "mission", title: "Mission Control", subtitle: "Open Mission Control", symbol: "squares.below.rectangle", keywords: ["mission control", "expose"]),
        SystemCommand(id: "launchpad", title: "Launchpad", subtitle: "Open Launchpad", symbol: "square.grid.3x3", keywords: ["launchpad"]),
        SystemCommand(id: "screenshot", title: "Screenshot", subtitle: "Capture an interactive screenshot", symbol: "camera.viewfinder", keywords: ["screenshot", "capture"]),
        SystemCommand(id: "mute", title: "Mute Volume", subtitle: "Toggle mute", symbol: "speaker.slash", keywords: ["mute", "volume"]),
        SystemCommand(id: "volumeup", title: "Volume Up", subtitle: "Raise the output volume", symbol: "speaker.plus", keywords: ["volume up", "louder"]),
        SystemCommand(id: "volumedown", title: "Volume Down", subtitle: "Lower the output volume", symbol: "speaker.minus", keywords: ["volume down", "quieter"]),
        SystemCommand(id: "playpause", title: "Play or Pause", subtitle: "Music", symbol: "playpause", keywords: ["play", "pause", "playpause"], category: "music"),
        SystemCommand(id: "nexttrack", title: "Next Track", subtitle: "Music", symbol: "forward.end", keywords: ["next", "next track"], category: "music"),
        SystemCommand(id: "previoustrack", title: "Previous Track", subtitle: "Music", symbol: "backward.end", keywords: ["previous", "prev", "previous track"], category: "music"),
        SystemCommand(id: "nowplaying", title: "Now Playing", subtitle: "Show the current Music track", symbol: "music.note", keywords: ["now playing", "np"], category: "music"),
    ]
}

public enum SettingsCatalog {
    public static let all: [SettingRecord] = [
        SettingRecord(id: "appearance", name: "Appearance", url: "x-apple.systempreferences:com.apple.Appearance-Settings.extension"),
        SettingRecord(id: "wallpaper", name: "Wallpaper", url: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension"),
        SettingRecord(id: "desktop", name: "Desktop & Dock", url: "x-apple.systempreferences:com.apple.Desktop-Settings.extension"),
        SettingRecord(id: "displays", name: "Displays", url: "x-apple.systempreferences:com.apple.Displays-Settings.extension"),
        SettingRecord(id: "screensaver", name: "Screen Saver", url: "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension"),
        SettingRecord(id: "battery", name: "Battery", url: "x-apple.systempreferences:com.apple.Battery-Settings.extension"),
        SettingRecord(id: "lock", name: "Lock Screen", url: "x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension"),
        SettingRecord(id: "touchid", name: "Touch ID & Password", url: "x-apple.systempreferences:com.apple.Touch-ID-Settings.extension"),
        SettingRecord(id: "users", name: "Users & Groups", url: "x-apple.systempreferences:com.apple.Users-Groups-Settings.extension"),
        SettingRecord(id: "passwords", name: "Passwords", url: "x-apple.systempreferences:com.apple.Passwords-Settings.extension"),
        SettingRecord(id: "internet", name: "Internet Accounts", url: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension"),
        SettingRecord(id: "siri", name: "Siri", url: "x-apple.systempreferences:com.apple.Siri-Settings.extension"),
        SettingRecord(id: "notifications", name: "Notifications", url: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"),
        SettingRecord(id: "sound", name: "Sound", url: "x-apple.systempreferences:com.apple.Sound-Settings.extension"),
        SettingRecord(id: "focus", name: "Focus", url: "x-apple.systempreferences:com.apple.Focus-Settings.extension"),
        SettingRecord(id: "screentime", name: "Screen Time", url: "x-apple.systempreferences:com.apple.Screen-Time-Settings.extension"),
        SettingRecord(id: "general", name: "General", url: "x-apple.systempreferences:com.apple.systempreferences.GeneralSettings"),
        SettingRecord(id: "accessibility", name: "Accessibility", url: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension"),
        SettingRecord(id: "controlcenter", name: "Control Centre", url: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension"),
        SettingRecord(id: "privacy", name: "Privacy & Security", url: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"),
        SettingRecord(id: "network", name: "Network", url: "x-apple.systempreferences:com.apple.Network-Settings.extension"),
        SettingRecord(id: "wifi", name: "Wi-Fi", url: "x-apple.systempreferences:com.apple.wifi-settings-extension"),
        SettingRecord(id: "bluetooth", name: "Bluetooth", url: "x-apple.systempreferences:com.apple.BluetoothSettings"),
        SettingRecord(id: "keyboard", name: "Keyboard", url: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"),
        SettingRecord(id: "mouse", name: "Mouse", url: "x-apple.systempreferences:com.apple.Mouse-Settings.extension"),
        SettingRecord(id: "trackpad", name: "Trackpad", url: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension"),
        SettingRecord(id: "printers", name: "Printers & Scanners", url: "x-apple.systempreferences:com.apple.Print-Scan-Settings.extension"),
        SettingRecord(id: "datetime", name: "Date & Time", url: "x-apple.systempreferences:com.apple.Date-Time-Settings.extension"),
        SettingRecord(id: "language", name: "Language & Region", url: "x-apple.systempreferences:com.apple.Localization-Settings.extension"),
        SettingRecord(id: "timemachine", name: "Time Machine", url: "x-apple.systempreferences:com.apple.Time-Machine-Settings.extension"),
        SettingRecord(id: "startup", name: "Startup Disk", url: "x-apple.systempreferences:com.apple.Startup-Disk-Settings.extension"),
        SettingRecord(id: "storage", name: "Storage", url: "x-apple.systempreferences:com.apple.settings.Storage"),
        SettingRecord(id: "softwareupdate", name: "Software Update", url: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension"),
        SettingRecord(id: "loginitems", name: "Login Items", url: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"),
        SettingRecord(id: "sharing", name: "Sharing", url: "x-apple.systempreferences:com.apple.Sharing-Settings.extension"),
        SettingRecord(id: "spotlight", name: "Spotlight", url: "x-apple.systempreferences:com.apple.Spotlight-Settings.extension"),
        SettingRecord(id: "transfer", name: "Transfer or Reset", url: "x-apple.systempreferences:com.apple.Transfer-Reset-Settings.extension"),
    ]
}
