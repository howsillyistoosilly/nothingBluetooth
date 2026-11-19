import AppKit
import SwiftUI

struct DeviceTab: View {
    @Bindable var manager: CMFBluetoothManager
    @State private var inspectorExpanded = false
    @Environment(\.openWindow) private var openWindow
    var showsDashboardButton = true

    var body: some View {
        VStack(spacing: 12) {
            MyDevicesCard(manager: manager)
            NothingCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(title: "ABOUT")
                    infoRow("Name", manager.deviceName)
                    infoRow("Model", manager.displayModelName)
                    infoRow("Firmware", manager.firmwareVersion ?? "-")
                    infoRow("Serial", manager.serialNumber ?? "-")
                    infoRow("MAC address", manager.deviceAddress ?? "-")
                    infoRow("Link", manager.statusDetail)
                }
            }
            NothingCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(title: "MENU BAR BATTERY")
                    PillSegments(options: BatteryDisplayMode.allCases.map { ($0, $0.rawValue) },
                                 selection: manager.batteryDisplay) { manager.batteryDisplay = $0 }
                    Text("L·R shows both buds, AVG the average, MIN the lower of the two.")
                        .font(.system(size: 10)).foregroundStyle(CMFTheme.muted)
                }
            }
            NothingCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(title: "APP")
                    ToggleRow(title: "Demo mode", caption: "Simulate a headset. Nothing is sent over Bluetooth.", isOn: $manager.isMockMode)
                    Divider().overlay(CMFTheme.line)
                    if showsDashboardButton {
                        Button("Open dashboard") {
                            openWindow(id: "dashboard")
                            NSApp.activate(ignoringOtherApps: true)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        Divider().overlay(CMFTheme.line)
                    }
                    HStack {
                        Button(manager.isConnected ? "Refresh status" : "Scan for headphones") {
                            manager.isConnected ? manager.refreshBattery() : manager.scanPairedDevices()
                        }
                        Spacer()
                        Button("Quit") { NSApplication.shared.terminate(nil) }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                }
            }
            NothingCard { inspector }
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 12)).foregroundStyle(CMFTheme.muted)
            Spacer(minLength: 12)
            Text(value).font(.system(size: 12, weight: .medium)).lineLimit(1).multilineTextAlignment(.trailing)
        }
    }

    private var inspector: some View {
        DisclosureGroup(isExpanded: $inspectorExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    Button("Clear") { manager.clearPacketLog() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CMFTheme.muted)
                }
                if manager.packetLog.isEmpty {
                    Text("No packets captured")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(CMFTheme.muted)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(manager.packetLog.reversed()) { entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(entry.direction)
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundStyle(entry.direction.hasPrefix("RX") ? CMFTheme.red : CMFTheme.muted)
                                        Spacer()
                                        Text(entry.date, style: .time)
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundStyle(CMFTheme.muted)
                                    }
                                    Text(entry.hex)
                                        .font(.system(size: 9, design: .monospaced))
                                        .textSelection(.enabled)
                                        .lineLimit(3)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 140)
                }
            }
            .padding(.top, 8)
        } label: {
            DotText(text: "PACKET INSPECTOR", dot: 1.9, gap: 0.9, color: CMFTheme.ink.opacity(0.85))
        }
        .tint(CMFTheme.muted)
    }
}
