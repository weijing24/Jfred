import Foundation

/// The launcher panel's position, independent of AppKit.
///
/// The user's position is the panel's top edge and horizontal center. Layout
/// builds a frame from those anchors and the current size, then slides it onto
/// the screen that already contains it. A list that grows into the Dock moves
/// the panel up only by the overflow. Summoning uses the same anchors, so the
/// panel is not sent to the top of the main display.
public struct LauncherPlacement: Equatable, Sendable {
    public var top: CGFloat
    public var centerX: CGFloat

    public init(top: CGFloat, centerX: CGFloat) {
        self.top = top
        self.centerX = centerX
    }

    /// Centered on `visible`, with the top edge `topInset` points below the menu bar.
    public static func initial(on visible: CGRect, topInset: CGFloat = 150) -> LauncherPlacement {
        LauncherPlacement(top: visible.maxY - topInset, centerX: visible.midX)
    }

    public func frame(width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: centerX - width / 2, y: top - height, width: width, height: height)
    }

    /// The visible frame with the largest intersection. Nil when `frame` misses
    /// every screen, such as after that display is unplugged.
    public static func screen(containing frame: CGRect, visibleFrames: [CGRect]) -> CGRect? {
        var best: CGRect?
        var bestArea: CGFloat = 0
        for visible in visibleFrames {
            let hit = visible.intersection(frame)
            guard !hit.isNull, hit.width > 0, hit.height > 0 else { continue }
            let area = hit.width * hit.height
            if area > bestArea {
                bestArea = area
                best = visible
            }
        }
        return best
    }

    public static func isOnScreen(_ frame: CGRect, visibleFrames: [CGRect]) -> Bool {
        screen(containing: frame, visibleFrames: visibleFrames) != nil
    }

    /// Slide `frame` into `visible`. A panel taller than the screen keeps its top on screen.
    /// A frame that does not fit is not sent to the opposite edge.
    public static func clamp(_ frame: CGRect, to visible: CGRect) -> CGRect {
        guard visible.width > 0, visible.height > 0, frame.width > 0, frame.height > 0 else { return frame }
        var frame = frame
        if frame.minX < visible.minX {
            frame.origin.x = visible.minX
        } else if frame.maxX > visible.maxX {
            frame.origin.x = visible.maxX - frame.width
        }
        if frame.minY < visible.minY {
            frame.origin.y = visible.minY
        }
        if frame.maxY > visible.maxY {
            frame.origin.y = visible.maxY - frame.height
        }
        return frame
    }

    /// The frame to display. When `frame` misses every screen, the proposed rect is
    /// returned unchanged so the caller can place it on the screen under the pointer.
    public func placedFrame(width: CGFloat, height: CGFloat, visibleFrames: [CGRect]) -> CGRect {
        let proposed = frame(width: width, height: height)
        guard let visible = Self.screen(containing: proposed, visibleFrames: visibleFrames) else {
            return proposed
        }
        return Self.clamp(proposed, to: visible)
    }
}
