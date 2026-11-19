import SwiftUI

@main
struct CMFControlApp: App {
    @State private var bluetooth = CMFBluetoothManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(manager: bluetooth)
        } label: {
            MenuBarLabel(manager: bluetooth)
        }
        .menuBarExtraStyle(.window)

        Window("NothingController", id: "dashboard") {
            DashboardView(manager: bluetooth)
        }
        .defaultSize(width: 1100, height: 760)
    }
}
