import AppKit
import SwiftUI
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let appState = AppState()

    let modelContainer: ModelContainer = {
        let schema = Schema([Tag.self, ResearchItem.self])
        let config = ModelConfiguration("GeminiResearch", isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupGemini()
        setupNotifications()
        startGatheringService()
        observeNotificationTaps()
    }

    // MARK: - Status Bar Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // SF Symbol: sparkles overlaid with "R" concept
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "For You")
            button.image = image?.withSymbolConfiguration(config)
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 580)
        popover.behavior = .transient
        popover.animates = true

        let contentView = PopoverView()
            .modelContainer(modelContainer)
            .environment(appState)

        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Summarise unsummarised items when popover opens
            Task {
                await GatheringService.shared.summariseUnsummarised()
            }
        }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Right-Click Context Menu

    private func showContextMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Sync Now", action: #selector(syncNow), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit For You", action: #selector(quitApp), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Reset so left-click works again
    }

    @objc private func syncNow() {
        Task { @MainActor in
            await GatheringService.shared.syncNow(appState: appState)
        }
    }

    @objc private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Services Setup

    private func setupGemini() {
        let key = SettingsManager.shared.geminiAPIKey
        if !key.isEmpty {
            GeminiService.shared.configure(apiKey: key)
        }
    }

    private func setupNotifications() {
        NotificationService.shared.requestPermission()
    }

    private func startGatheringService() {
        GatheringService.shared.start(modelContainer: modelContainer)
    }

    // MARK: - Handle Notification Taps

    private func observeNotificationTaps() {
        NotificationCenter.default.addObserver(
            forName: NotificationService.showItemNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            if let idString = notification.userInfo?["itemId"] as? String,
               let uuid = UUID(uuidString: idString) {
                self.appState.scrollToItemId = uuid
            }
            self.showPopover()
        }
    }
}
