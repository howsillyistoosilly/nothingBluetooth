import SwiftUI

struct ControlsTab: View {
    @Bindable var manager: CMFBluetoothManager
    /// Two columns for the dashboard, where the page has to fit without scrolling.
    var wide = false

    var body: some View {
        Group {
            if wide {
                HStack(alignment: .top, spacing: 14) {
                    GestureCard(manager: manager).frame(maxWidth: .infinity)
                    VStack(spacing: 14) {
                        connectionCard
                        wearCard
                        if !manager.isOverEar { FindMyBudsCard(manager: manager) }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 12) {
                    GestureCard(manager: manager)
                    connectionCard
                    wearCard
                    if !manager.isOverEar { FindMyBudsCard(manager: manager) }
                }
            }
        }
        .disabled(!manager.isConnected)
        .opacity(manager.isConnected ? 1 : 0.5)
    }

    private var connectionCard: some View {
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
    }

    private var wearCard: some View {
        NothingCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(title: manager.isOverEar ? "WEAR DETECTION" : "IN-EAR DETECTION", trailing: "On removal")
                ToggleRow(title: manager.isOverEar ? "Auto pause" : "In-ear detection",
                          caption: "Pause playback when you take them off. Saved and re-applied each time the device connects.",
                          isOn: Binding(get: { manager.inEarDetectionEnabled }, set: manager.setInEarDetection),
                          isAvailable: manager.supportsInEarDetection)
            }
        }
    }
}
