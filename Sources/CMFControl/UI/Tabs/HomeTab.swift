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

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(CMFTheme.surface)
            DotGrid().clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            RadialGradient(colors: [.white.opacity(0.16), .clear], center: .center, startRadius: 0, endRadius: 130)
            DeviceArtwork(modelName: manager.displayModelName)
                .padding(.horizontal, 60)
                .padding(.vertical, 10)
            VStack(alignment: .leading, spacing: 8) {
                StatusPill(text: manager.connectionState.rawValue, active: manager.isConnected)
                if let error = manager.lastError {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(CMFTheme.red)
                        .lineLimit(2)
                        .frame(maxWidth: 150, alignment: .leading)
                }
            }
            .padding(14)
            VStack {
                Spacer()
                Text(manager.displayModelName.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(CMFTheme.muted)
                    .lineLimit(1)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 230)
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
                PillSegments(
                    options: [(NoiseGroup.anc, "Noise cancel"), (.transparency, "Transparency"), (.off, "Off")],
                    selection: NoiseGroup(manager.noiseMode)
                ) { group in
                    switch group {
                    case .anc: manager.setNoiseMode(manager.noiseMode.isANC ? manager.ancIntensity : .mid)
                    case .transparency: manager.setNoiseMode(.transparency)
                    case .off: manager.setNoiseMode(.off)
                    }
                }
                if manager.noiseMode.isANC {
                    PillSegments(
                        options: [(ANCMode.low, "Low"), (.mid, "Mid"), (.high, "High"), (.adaptive, "Adaptive")],
                        selection: manager.ancIntensity
                    ) { manager.setANCIntensity($0) }
                }
            }
            .disabled(!manager.isConnected)
            .opacity(manager.isConnected ? 1 : 0.5)
        }
    }
}

private enum NoiseGroup: Hashable {
    case anc, transparency, off

    init(_ mode: ANCMode) {
        switch mode {
        case .off: self = .off
        case .transparency: self = .transparency
        default: self = .anc
        }
    }
}
