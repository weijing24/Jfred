import Foundation

/// Whether a request to quit Jfred should end the process.
///
/// ⌘Q and the Dock's Quit only close Preferences and leave the menu bar app
/// running. A log out, restart or shut down sends the same quit event, and
/// cancelling that would cancel the whole session change, so those quit.
public enum QuitPolicy {
    /// `kAEQuitReason` values (AERegistry.h) that mean the user's session is
    /// ending: kAELogOut 'logo', kAEReallyLogOut 'rlgo', kAEShowRestartDialog
    /// 'rrst', kAEShowShutdownDialog 'rsdn', kAERestart 'rest', kAEShutDown 'shut'.
    public static let sessionEndingReasons: Set<UInt32> = [
        0x6C6F_676F,
        0x726C_676F,
        0x7272_7374,
        0x7273_646E,
        0x7265_7374,
        0x7368_7574,
    ]

    /// - Parameters:
    ///   - explicitQuit: the status menu's Quit Jfred, or the updater, asked to quit.
    ///   - systemPoweringOff: `NSWorkspace.willPowerOffNotification` has arrived.
    ///   - quitReason: the quit Apple event's `kAEQuitReason`, if any.
    public static func shouldTerminate(explicitQuit: Bool, systemPoweringOff: Bool, quitReason: UInt32?) -> Bool {
        if explicitQuit || systemPoweringOff { return true }
        guard let quitReason else { return false }
        return sessionEndingReasons.contains(quitReason)
    }
}
