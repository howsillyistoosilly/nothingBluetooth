import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Open as a normal app first (Dock icon and the main window); the menu bar item runs alongside it.
        NSApp.setActivationPolicy(.regular)
        // The bare package executable has no bundle icon, so set it from the asset catalog.
        if let icon = ProductCatalog.image(named: "app-icon") { NSApp.applicationIconImage = icon }
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow, window.title == "NothingController" else { return }
            // Closing the main window leaves just the menu bar item.
            MainActor.assumeIsolated { NSApp.setActivationPolicy(.accessory) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct CMFControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var bluetooth = CMFBluetoothManager()

    var body: some Scene {
        // The main window comes first, then the menu bar item.
        Window("NothingController", id: "dashboard") {
            DashboardView(manager: bluetooth)
        }
        .defaultSize(width: 1280, height: 760)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarView(manager: bluetooth)
        } label: {
            MenuBarLabel(manager: bluetooth)
        }
        .menuBarExtraStyle(.window)
    }
}
