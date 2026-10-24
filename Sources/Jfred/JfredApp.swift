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
                .frame(minWidth: 980, minHeight: 640)
        }
        .defaultSize(width: 1120, height: 740)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appTermination) {
                Button("Quit Jfred") { delegate.model.quit() }
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
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventID == kAEOpenApplication {
            let loginItemCode = FourCharCode(0x6C676974) // 'lgit'
            let flag = event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == loginItemCode
                || event.attributeDescriptor(forKeyword: loginItemCode) != nil
            AppRuntime.launchedAsLoginItem = flag
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        if AppRuntime.explicitQuit { return .terminateNow }
        if let event = NSApp.currentEvent, event.type == .keyDown, event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "q" {
            return .terminateNow
        }
        // Dock Quit and the last preferences window closing must not kill the hotkey.
        model.leaveDock()
        return .terminateCancel
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.pathExtension.lowercased() == "alfredworkflow" {
                model.importWorkflow(at: url)
                continue
            }
            guard url.scheme == "jfredlocal" else { continue }
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let query = String((items.first { $0.name == "q" }?.value ?? "").prefix(512))
            if url.host == "search" || url.host == nil {
                model.query = query
                model.showLauncher()
            } else if url.host == "music" {
                model.showMusicPlayer()
            } else if url.host == "actions" {
                model.query = query
                model.showLauncher()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.model.showActions() }
            } else if url.host == "run", let keyword = items.first(where: { $0.name == "keyword" })?.value {
                model.query = keyword + " "
                model.showLauncher()
            }
        }
    }
}
