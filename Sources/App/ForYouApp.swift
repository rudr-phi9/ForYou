import SwiftUI
import SwiftData

@main
struct ForYouApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window — accessible via right-click → Preferences
        Settings {
            TagsSettingsView()
                .modelContainer(appDelegate.modelContainer)
                .environment(appDelegate.appState)
                .frame(width: 480, height: 520)
        }
    }
}
