import AlfredCore
import AppKit
import SwiftUI

@main
struct AlfredApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("Alfred Preferences", id: "preferences") {
            PreferencesShell(model: delegate.model)
                .frame(minWidth: 980, minHeight: 640)
        }
        .defaultSize(width: 1120, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appSettings) {
                Button("Show Alfred") { delegate.model.toggleLauncher() }
            }
            CommandMenu("Search") {
                Button("Show Alfred") { delegate.model.showLauncher() }
                Button("Preferences Search") { delegate.model.showPreferences() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppRuntime.model = model
        model.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "alfredlocal" else { continue }
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let query = items.first { $0.name == "q" }?.value ?? ""
            if url.host == "search" || url.host == nil {
                model.query = query
                model.showLauncher()
            } else if url.host == "run", let keyword = items.first(where: { $0.name == "keyword" })?.value {
                model.query = keyword + " "
                model.showLauncher()
            }
        }
    }
}
