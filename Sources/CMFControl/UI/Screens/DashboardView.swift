import AppKit
import SwiftUI

/// Full-size window with every panel visible at once; appears in the Dock while open.
struct DashboardView: View {
    @Bindable var manager: CMFBluetoothManager

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                if manager.isConnected {
                    HStack(alignment: .top, spacing: 16) {
                        column { HomeTab(manager: manager); MyDevicesCard(manager: manager) }
                        column { SoundTab(manager: manager) }
                        column { ControlsTab(manager: manager); DeviceTab(manager: manager, showsDashboardButton: false) }
                    }
                    .padding(20)
                } else {
                    EmptyStateView(manager: manager)
                        .frame(maxWidth: 520)
                        .padding(24)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .background(CMFTheme.background)
        .foregroundStyle(CMFTheme.ink)
        .preferredColorScheme(.dark)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear { NSApp.setActivationPolicy(.accessory) }
    }

    private func column<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 12) { content() }.frame(maxWidth: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack {
            DotText(text: "NOTHING", dot: 2.8, gap: 1.3)
            DotText(text: "DASHBOARD", dot: 1.6, gap: 0.8, color: CMFTheme.muted).padding(.leading, 10).padding(.top, 8)
            Spacer()
            StatusPill(text: manager.isConnected ? manager.deviceName : manager.connectionState.rawValue, active: manager.isConnected)
            if let text = manager.menuBarBatteryText {
                Text(text).font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) { Rectangle().fill(CMFTheme.line).frame(height: 1) }
    }
}
