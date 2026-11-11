import CoreServices
import Foundation
import Testing
@testable import JfredCore

struct QuitPolicyTests {
    @Test func sessionEndingReasonsMatchTheAppleEventConstants() {
        let expected: Set<UInt32> = [
            UInt32(kAELogOut), UInt32(kAEReallyLogOut),
            UInt32(kAEShowRestartDialog), UInt32(kAEShowShutdownDialog),
            UInt32(kAERestart), UInt32(kAEShutDown),
        ]
        #expect(QuitPolicy.sessionEndingReasons == expected)
    }

    @Test func logOutRestartAndShutDownQuit() {
        for reason in QuitPolicy.sessionEndingReasons {
            #expect(QuitPolicy.shouldTerminate(explicitQuit: false, systemPoweringOff: false, quitReason: reason))
        }
    }

    @Test func commandQAndDockQuitStayResident() {
        // ⌘Q has no quit Apple event; the Dock sends one without a reason.
        #expect(!QuitPolicy.shouldTerminate(explicitQuit: false, systemPoweringOff: false, quitReason: nil))
        // Some other reason, such as a "quit all apps" request, is not a session end.
        #expect(!QuitPolicy.shouldTerminate(explicitQuit: false, systemPoweringOff: false, quitReason: UInt32(kAEQuitAll)))
    }

    @Test func explicitQuitAndPowerOffAlwaysQuit() {
        #expect(QuitPolicy.shouldTerminate(explicitQuit: true, systemPoweringOff: false, quitReason: nil))
        #expect(QuitPolicy.shouldTerminate(explicitQuit: false, systemPoweringOff: true, quitReason: nil))
        #expect(QuitPolicy.shouldTerminate(explicitQuit: true, systemPoweringOff: true, quitReason: UInt32(kAEQuitAll)))
    }
}
