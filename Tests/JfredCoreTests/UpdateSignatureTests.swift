import Foundation
import Testing
@testable import JfredCore

struct UpdateSignatureTests {
    @Test func requirementMatchesTheCodesignScript() throws {
        let script = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // JfredCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("scripts/codesign-app.sh")
        let text = try String(contentsOf: script, encoding: .utf8)
        let prefix = "release_requirement='"
        let lines = text.split(separator: "\n").filter { $0.hasPrefix(prefix) }
        try #require(lines.count == 1, "scripts/codesign-app.sh must set release_requirement exactly once")
        let line = lines[0]
        #expect(line.hasSuffix("'"))
        let value = String(line.dropFirst(prefix.count).dropLast())
        #expect(value == UpdateSignature.requirement)
    }

    @Test func requirementPinsTheBundleIdAndOneCertificate() {
        let prefix = "identifier \"\(AppUpdateFeed.bundleIdentifier)\" and certificate leaf = H\""
        let requirement = UpdateSignature.requirement
        #expect(requirement.hasPrefix(prefix))
        #expect(requirement.hasSuffix("\""))
        let hash = String(requirement.dropFirst(prefix.count).dropLast())
        #expect(hash.range(of: "^[0-9a-f]{40}$", options: .regularExpression) != nil)
    }

    @Test func verifyArgumentsPinTheRequirementAsLiteralSource() {
        let arguments = UpdateSignature.verifyArguments(appPath: "/tmp/JfredUpdate-x/Jfred.app")
        #expect(arguments == [
            "--verify", "--deep", "--strict",
            "--test-requirement", "=" + UpdateSignature.requirement,
            "/tmp/JfredUpdate-x/Jfred.app",
        ])
    }

    /// An ad-hoc signature is valid, so a plain `--verify --deep --strict`
    /// accepts it. The pinned check must reject it with codesign's
    /// "requirement not satisfied" status, which also proves the arguments parse.
    @Test func adHocSignedBundleFailsThePinnedCheck() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("jfred-signature-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Jfred.app", isDirectory: true)
        let macOS = app.appendingPathComponent("Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: "/usr/bin/true", toPath: macOS.appendingPathComponent("Jfred").path)
        let plist: [String: Any] = [
            "CFBundleIdentifier": AppUpdateFeed.bundleIdentifier,
            "CFBundleExecutable": "Jfred",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "0.0.1",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: app.appendingPathComponent("Contents/Info.plist"))

        #expect(try codesign(["--force", "--sign", "-", app.path]) == 0)
        #expect(try codesign(["--verify", "--deep", "--strict", app.path]) == 0)
        #expect(try codesign(UpdateSignature.verifyArguments(appPath: app.path)) == UpdateSignature.requirementNotSatisfiedStatus)
    }

    private func codesign(_ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
