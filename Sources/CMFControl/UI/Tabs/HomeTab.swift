import SwiftUI

struct HomeTab: View {
    @Bindable var manager: CMFBluetoothManager

    var body: some View {
        VStack(spacing: 12) {
            hero
            battery
            noiseControl
        }
    }

    /// Product card in the Beoplay style: model top-left, status badge top-right, readouts along the bottom.
    private var hero: some View {
        ZStack {
            RadialGradient(colors: [.white.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 150)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            DeviceArtwork(modelName: manager.artworkModelName)
                .padding(.horizontal, 70)
                .padding(.top, 34)
                .padding(.bottom, 44)
            VStack {
                HStack(alignment: .top) {
                    DotText(text: manager.displayModelName, dot: 1.7, gap: 0.8)
                    Spacer()
                    outlineBadge(manager.connectionState.rawValue.uppercased())
                }
                Spacer()
                HStack(alignment: .bottom) {
                    if let text = manager.menuBarBatteryText {
                        BigFigure(value: text.replacingOccurrences(of: "%", with: ""), unit: text.contains("%") ? "%" : nil,
                                  caption: "Battery", size: 26)
                    }
                    Spacer()
                    if let error = manager.lastError {
                        Text(error).font(.system(size: 9)).foregroundStyle(CMFTheme.red).lineLimit(2).frame(maxWidth: 150, alignment: .trailing)
                    } else {
                        Text("BLUETOOTH")
                            .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1)
                            .foregroundStyle(CMFTheme.muted)
                    }
                }
            }
            .padding(16)
        }
        .frame(height: 250)
        .glass(radius: 30)
    }

    private func outlineBadge(_ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(manager.isConnected ? CMFTheme.red : CMFTheme.muted).frame(width: 5, height: 5)
            Text(text).font(.system(size: 8.5, weight: .semibold, design: .monospaced)).tracking(0.8)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
    }

    private var battery: some View {
        NothingCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "BATTERY", trailing: manager.firmwareVersion.map { "FW \($0)" })
                if let battery = manager.battery {
                    HStack(alignment: .top) {
                        if let headset = battery.headset { BatteryDial(title: "HEADSET", component: headset) }
                        if let left = battery.left { BatteryDial(title: "LEFT", component: left) }
                        if let right = battery.right { BatteryDial(title: "RIGHT", component: right) }
                        if let caseBattery = battery.caseBattery { BatteryDial(title: "CASE", component: caseBattery) }
                    }
                } else {
                    HStack(spacing: 8) {
                        Text(manager.batteryMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(CMFTheme.muted)
                        Spacer()
                        if manager.isConnected && !manager.isMockMode {
                            Button { manager.refreshBattery() } label: {
                                Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .help("Request battery status")
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var noiseControl: some View {
        NothingCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "NOISE CONTROL", trailing: manager.noiseMode.rawValue)
                NoiseModeSelector(manager: manager)
            }
            .disabled(!manager.isConnected)
            .opacity(manager.isConnected ? 1 : 0.5)
        }
    }
}
