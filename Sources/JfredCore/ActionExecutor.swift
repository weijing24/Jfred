import Foundation

/// What to do with one selected file. The caller performs the steps.
public enum FileOpenStep: Equatable, Sendable {
    case reveal
    case runAppleScript
    case open
    case touch
    case touchResolvedTarget
}

public struct FileOpenPolicy: Equatable, Sendable {
    public var revealInsteadOfOpening: Bool
    public var openFoldersInFinder: Bool
    public var runAppleScripts: Bool
    public var touchFolders: Bool
    public var touchAliases: Bool

    public init(
        revealInsteadOfOpening: Bool,
        openFoldersInFinder: Bool,
        runAppleScripts: Bool,
        touchFolders: Bool,
        touchAliases: Bool
    ) {
        self.revealInsteadOfOpening = revealInsteadOfOpening
        self.openFoldersInFinder = openFoldersInFinder
        self.runAppleScripts = runAppleScripts
        self.touchFolders = touchFolders
        self.touchAliases = touchAliases
    }

    public init(preferences: Preferences) {
        self.init(
            revealInsteadOfOpening: preferences.fileOpenWithFinder,
            openFoldersInFinder: preferences.fileOpenFoldersInFinder,
            runAppleScripts: preferences.fileRunAppleScriptsInsteadOfOpening,
            touchFolders: preferences.fileTouchFolders,
            touchAliases: preferences.fileTouchAliases
        )
    }

    /// Steps for one path. When `revealInsteadOfOpening` is set, every path is
    /// revealed and nothing is touched; the caller may reveal the whole selection at once.
    public func steps(exists: Bool, isDirectory: Bool, isAppleScript: Bool, resolvesElsewhere: Bool) -> [FileOpenStep] {
        if revealInsteadOfOpening { return [.reveal] }
        var steps: [FileOpenStep] = []
        if exists, isDirectory, openFoldersInFinder {
            steps.append(.reveal)
        } else if exists, !isDirectory, runAppleScripts, isAppleScript {
            steps.append(.runAppleScript)
        } else {
            steps.append(.open)
        }
        if exists, isDirectory, touchFolders { steps.append(.touch) }
        if exists, !isDirectory, touchAliases, resolvesElsewhere { steps.append(.touchResolvedTarget) }
        return steps
    }
}

public enum SystemEffect: Equatable, Sendable {
    case setOutputVolume(Int)
    case sleep
    case restart
    case shutdown
    case logout
    case lock
    case screensaver
    case emptyTrash
    case showTrash
    case eject(all: Bool)
    case quitAll
    case toggleDarkMode
    case toggleHiddenFiles
    case showDesktop
    case missionControl
    case launchpad
    case screenshot
    case mute
    case volumeUp
    case volumeDown
    case unknown(String)
}

public enum ActionExecutor {
    /// `nil` means the command is disabled or the volume payload is not 0...100.
    /// Confirmation stays with the caller; this function only chooses the effect.
    public static func systemEffect(id: String, disabled: [String], ejectScope: String) -> SystemEffect? {
        if disabled.contains(id) { return nil }
        if id.hasPrefix("volume:") {
            guard let value = Int(id.dropFirst("volume:".count)), (0...100).contains(value) else { return nil }
            return .setOutputVolume(value)
        }
        switch id {
        case "sleep": return .sleep
        case "restart": return .restart
        case "shutdown": return .shutdown
        case "logout": return .logout
        case "lock": return .lock
        case "screensaver": return .screensaver
        case "emptetrash": return .emptyTrash
        case "trash": return .showTrash
        case "eject", "ejectall":
            return .eject(all: id == "ejectall" || ejectScope == "all")
        case "quitall": return .quitAll
        case "darkmode": return .toggleDarkMode
        case "hidden": return .toggleHiddenFiles
        case "desktop": return .showDesktop
        case "mission": return .missionControl
        case "launchpad": return .launchpad
        case "screenshot": return .screenshot
        case "mute": return .mute
        case "volumeup": return .volumeUp
        case "volumedown": return .volumeDown
        default: return .unknown(id)
        }
    }
}

public enum ClipboardRetention {
    public static func interval(for label: String) -> TimeInterval? {
        switch label {
        case "1 day": return 86_400
        case "1 week": return 7 * 86_400
        case "1 month": return 30 * 86_400
        case "3 months": return 90 * 86_400
        case "1 year": return 365 * 86_400
        default: return nil
        }
    }

    public static func label(forKind kind: String, preferences: Preferences) -> String {
        switch kind {
        case "image": return preferences.clipboardRetentionImages
        case "file": return preferences.clipboardRetentionFiles
        default: return preferences.clipboardRetentionText
        }
    }
}
