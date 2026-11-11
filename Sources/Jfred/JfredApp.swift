import JfredCore
import AppKit
import SwiftUI

@main
struct JfredApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        let _ = registerPreferencesOpener()
        Window("Jfred Preferences", id: "preferences") {
            PreferencesShell(model: delegate.model)
                .frame(minWidth: 1180, minHeight: 700)
        }
        .defaultSize(width: 1422, height: 860)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appTermination) {
                Button("Close Jfred Preferences") { delegate.model.leaveDock() }
                    .keyboardShortcut("q", modifiers: .command)
            }
            CommandGroup(after: .appSettings) {
                Button("Show Jfred") { delegate.model.toggleLauncher() }
            }
            CommandMenu("Search") {
                Button("Show Jfred") { delegate.model.showLauncher() }
                Button("Preferences Search") { delegate.model.showPreferences() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private func registerPreferencesOpener() {
        AppRuntime.openPreferences = { [openWindow] in
            openWindow(id: "preferences")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()


    func applicationWillFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--render-prefs") {
            AppRuntime.renderPreferencesOnly = true
            NSApp.setActivationPolicy(.prohibited)
        }
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventID == kAEOpenApplication {
            let loginItemCode = FourCharCode(0x6C676974) // 'lgit'
            let flag = event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == loginItemCode
                || event.attributeDescriptor(forKeyword: loginItemCode) != nil
            AppRuntime.launchedAsLoginItem = flag
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppRuntime.renderPreferencesOnly {
            let args = CommandLine.arguments
            let dir = args.dropFirst().first(where: { $0.hasPrefix("/") && $0 != args.first })
                ?? FileManager.default.temporaryDirectory.appendingPathComponent("jfred-prefs-render").path
            do {
                try PreferencesSnapshot.render(model: model, directory: URL(fileURLWithPath: dir))
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("Jfred: failed to render Preferences: \(error)\n".utf8))
                exit(1)
            }
        }
        // Log out, restart and shut down announce themselves here before the
        // quit event arrives; either one lets Jfred quit.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { AppRuntime.systemPoweringOff = true }
        }
        // A raw bitmap assigned here skips the system squircle, so the Dock draws a square.
        AppRuntime.model = model
        model.start()
        // Launching Jfred from a launcher should show its settings, the same
        // way it would if the window had been restored from the last session.
        guard !AppRuntime.launchedAsLoginItem else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.model.showPreferences()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Launching the already running app from a launcher should bring its
        // settings forward instead of doing nothing.
        model.showPreferences()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if QuitPolicy.shouldTerminate(
            explicitQuit: AppRuntime.explicitQuit,
            systemPoweringOff: AppRuntime.systemPoweringOff,
            quitReason: Self.currentQuitReason()
        ) {
            return .terminateNow
        }
        // Cmd+Q closes Preferences while keeping the menu bar app and its
        // global hotkeys alive. The status menu's "Quit Jfred" sets
        // explicitQuit and still terminates the process.
        model.leaveDock()
        return .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard !AppRuntime.renderPreferencesOnly else { return }
        model.prepareForTermination()
    }

    /// `kAEQuitReason` of the quit Apple event being handled. loginwindow sets
    /// it for log out, restart and shut down; ⌘Q has no Apple event and the
    /// Dock's Quit sends none.
    private static func currentQuitReason() -> UInt32? {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventClass == kCoreEventClass,
              event.eventID == kAEQuitApplication else { return nil }
        let keyword = AEKeyword(kAEQuitReason)
        guard let reason = event.attributeDescriptor(forKeyword: keyword) ?? event.paramDescriptor(forKeyword: keyword) else { return nil }
        let code = reason.typeCodeValue != 0 ? reason.typeCodeValue : reason.enumCodeValue
        return code == 0 ? nil : code
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if WorkflowPackage.isImportableFile(url) {
                model.importWorkflow(at: url)
                continue
            }
            guard url.scheme == "jfredlocal" else { continue }
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let query = String((items.first { $0.name == "q" }?.value ?? "").prefix(512))
            if url.host == "search" || url.host == nil {
                model.query = query
                model.showLauncher()
            } else if url.host == "selection" {
                model.showSelectionActions()
            } else if url.host == "actions" {
                model.query = query
                model.showLauncher()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.model.showActions() }
            } else if url.host == "run", let keyword = items.first(where: { $0.name == "keyword" })?.value {
                model.query = keyword + " "
                model.showLauncher()
            } else if url.host == "workflows" {
                model.section = .workflows
                model.showPreferences()
                if let configure = items.first(where: { $0.name == "configure" })?.value {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.model.openWorkflowConfig(showsWorkflow: configure == "workflow")
                    }
                }
            }
        }
    }
}
