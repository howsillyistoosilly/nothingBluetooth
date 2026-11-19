import SwiftUI

struct ControlsTab: View {
    @Bindable var manager: CMFBluetoothManager

    var body: some View {
        VStack(spacing: 12) {
            GestureCard(manager: manager)
            NothingCard {
                VStack(alignment: .leading, spacing: 16) {
                    SectionLabel(title: "CONNECTION")
                    ToggleRow(title: "Low Lag Mode",
                              caption: "Reduces audio delay for gaming and video.",
                              isOn: Binding(get: { manager.lowLatencyEnabled }, set: manager.setLowLatency))
                    Divider().overlay(CMFTheme.line)
                    ToggleRow(title: "Dual Connection",
                              caption: manager.supportsDualConnection ? "Stay connected to two devices at once." : "Not mapped for this profile yet.",
                              isOn: Binding(get: { manager.dualConnectionEnabled }, set: manager.setDualConnection),
                              isAvailable: manager.supportsDualConnection)
                }
            }
            NothingCard {
                VStack(alignment: .leading, spacing: 16) {
                    SectionLabel(title: manager.isOverEar ? "WEAR DETECTION" : "IN-EAR DETECTION", trailing: "ON REMOVAL")
                    ToggleRow(title: manager.isOverEar ? "Auto pause" : "In-ear detection",
                              caption: "Pause playback when you take them off. Saved and re-applied each time the device connects.",
                              isOn: Binding(get: { manager.inEarDetectionEnabled }, set: manager.setInEarDetection),
                              isAvailable: manager.supportsInEarDetection)
                }
            }
            if !manager.isOverEar { FindMyBudsCard(manager: manager) }
        }
        .disabled(!manager.isConnected)
        .opacity(manager.isConnected ? 1 : 0.5)
    }
}
