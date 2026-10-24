import AppKit
import Foundation

/// Minimal Music.app bridge used by the launcher's music commands and by the
/// Music preference page. Nothing is cached, so the mini player always
/// reflects the player's real state.
enum MusicService {
    static func isRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
    }

    @discardableResult
    static func playPause() -> String {
        Shell.osascript("""
        tell application "Music"
          if it is not running then launch
          playpause
        end tell
        """)
    }

    @discardableResult
    static func next() -> String {
        Shell.osascript("""
        tell application "Music"
          if it is not running then launch
          next track
        end tell
        """)
    }

    @discardableResult
    static func previous() -> String {
        Shell.osascript("""
        tell application "Music"
          if it is not running then launch
          previous track
        end tell
        """)
    }

    static func currentTrack() -> String {
        let text = Shell.osascript("""
        tell application "Music"
          if it is running then
            if player state is playing then
              return (name of current track) & " — " & (artist of current track)
            else
              return name of current track
            end if
          end if
        end tell
        """)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func playSearch(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { _ = playPause(); return true }
        let escaped = appleScriptEscaped(q)
        let result = Shell.osascript("""
        tell application "Music"
          if it is not running then launch
          set matches to (every track whose name contains "\(escaped)")
          if (count of matches) is greater than 0 then
            play item 1 of matches
            return "playing"
          end if
          set albumMatches to (every album whose name contains "\(escaped)")
          if (count of albumMatches) is greater than 0 then
            play item 1 of albumMatches
            return "playing"
          end if
        end tell
        """, timeout: 8)
        return result.contains("playing")
    }

    private static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
