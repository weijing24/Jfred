import Foundation
import Testing
@testable import JfredCore

struct LauncherPlacementTests {
    private let main = CGRect(x: 0, y: 80, width: 1440, height: 800)
    private let side = CGRect(x: 1440, y: 80, width: 1920, height: 1050)

    @Test func initialPlacementSitsBelowTheMenuBarAndCentered() {
        let visible = CGRect(x: 100, y: 80, width: 1440, height: 800)
        let placement = LauncherPlacement.initial(on: visible)
        #expect(placement.top == visible.maxY - 150)
        #expect(placement.centerX == visible.midX)
    }

    @Test func secondaryDisplayKeepsItsOwnScreen() {
        let placement = LauncherPlacement(top: 800, centerX: 2400)
        let frame = placement.placedFrame(width: 640, height: 200, visibleFrames: [main, side])
        #expect(frame.midX == 2400)
        #expect(frame.maxY == 800)
        #expect(side.contains(frame))
        #expect(!main.intersects(frame))
    }

    /// A hidden panel has no `screen`. Clamping that frame to the main display
    /// used to park it on the main display's right edge on every summon.
    @Test func frameOnAnotherDisplayIsNotPulledOntoTheMainDisplay() {
        let placement = LauncherPlacement(top: 800, centerX: 2400)
        let frame = placement.placedFrame(width: 640, height: 200, visibleFrames: [main])
        #expect(frame.midX == 2400)
        #expect(frame.maxY == 800)
        #expect(!main.intersects(frame))
    }

    /// The old clamp used `max(minY, maxY - height)`, which sends an overflowing
    /// list to the top of the screen and then saves that as the next position.
    @Test func growingIntoTheDockSlidesUpWithoutJumpingToTheTop() {
        let visible = CGRect(x: 0, y: 100, width: 1400, height: 900)
        let placement = LauncherPlacement(top: 400, centerX: 700)
        let frame = placement.placedFrame(width: 640, height: 500, visibleFrames: [visible])
        #expect(frame.minY == 100)
        #expect(frame.maxY == 600)
        #expect(frame.midX == 700)
        #expect(frame.maxY != visible.maxY)
    }

    @Test func tallerThanTheScreenKeepsTheQueryFieldOnScreen() {
        let visible = CGRect(x: 0, y: 100, width: 1400, height: 900)
        let placement = LauncherPlacement(top: 900, centerX: 700)
        let frame = placement.placedFrame(width: 640, height: 1200, visibleFrames: [visible])
        #expect(frame.maxY == visible.maxY)
    }

    @Test func leftOverhangStaysOnThatScreen() {
        let frame = CGRect(x: -10, y: 600, width: 640, height: 120)
        #expect(LauncherPlacement.isOnScreen(frame, visibleFrames: [main]))
        let clamped = LauncherPlacement.clamp(frame, to: main)
        #expect(clamped.minX == main.minX)
        #expect(clamped.maxY == frame.maxY)
    }

    @Test func unpluggedDisplayIsNotOnScreen() {
        let gone = CGRect(x: -3000, y: 400, width: 640, height: 120)
        #expect(!LauncherPlacement.isOnScreen(gone, visibleFrames: [main, side]))
    }

    @Test func sameAnchorsDoNotWalkWhenTheSizeChanges() {
        let visible = CGRect(x: 0, y: 80, width: 1440, height: 900)
        let placement = LauncherPlacement(top: 700, centerX: 500)
        let short = placement.placedFrame(width: 559, height: 120, visibleFrames: [visible])
        let tall = placement.placedFrame(width: 559, height: 480, visibleFrames: [visible])
        let wide = placement.placedFrame(width: 919, height: 480, visibleFrames: [visible])
        #expect(short.maxY == 700)
        #expect(tall.maxY == 700)
        #expect(short.midX == 500)
        #expect(tall.midX == 500)
        #expect(wide.midX == 500)
        let again = placement.placedFrame(width: 919, height: 480, visibleFrames: [visible])
        #expect(again == wide)
    }
}
