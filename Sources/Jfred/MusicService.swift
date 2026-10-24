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

}

extension MusicService {
    struct Info: Sendable {
        var title: String
        var artist: String
        var playing: Bool
    }

    static func info() -> Info {
        let text = Shell.osascript("""
        tell application "Music"
          if it is running then
            if player state is playing then
              return (name of current track) & tab & (artist of current track) & tab & "playing"
            else
              return (name of current track) & tab & (artist of current track) & tab & "paused"
            end if
          end if
        end tell
        """)
        let parts = text.components(separatedBy: "\t")
        return Info(
            title: parts.count > 0 ? parts[0].trimmingCharacters(in: .whitespacesAndNewlines) : "",
            artist: parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : "",
            playing: text.contains("playing")
        )
    }

    struct Track: Identifiable, Sendable {
        var id: String { "\(title) — \(artist)" }
        var title: String
        var artist: String
    }

    static func searchTracks(_ query: String) -> [Track] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let escaped = appleScriptEscaped(q)
        let text = Shell.osascript("""
        tell application "Music"
          if it is not running then return ""
          set matches to (every track whose name contains "\(escaped)")
          set output to ""
          set total to count of matches
          if total > 20 then set total to 20
          repeat with i from 1 to total
            set t to item i of matches
            set output to output & (name of t) & tab & (artist of t) & linefeed
          end repeat
          return output
        end tell
        """, timeout: 10)
        return text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard let title = parts.first, !title.isEmpty else { return nil }
            return Track(title: String(title), artist: parts.count > 1 ? String(parts[1]) : "")
        }
    }

    static func artworkURL() -> String? {
        let path = NSTemporaryDirectory() + "jfred-music-art.png"
        try? FileManager.default.removeItem(atPath: path)
        let escaped = appleScriptEscaped(path)
        _ = Shell.osascript("""
        tell application "Music"
          if it is running then
            try
              set art to data of artwork 1 of current track
              set f to open for access POSIX file "\(escaped)" with write permission
              set eof f to 0
              write art to f
              close access f
            end try
          end if
        end tell
        """, timeout: 5)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? Int,
              size > 0 else { return nil }
        return path
    }

    static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
