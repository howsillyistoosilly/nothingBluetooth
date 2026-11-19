import AppKit
import SwiftUI

private enum DashboardPage: String, CaseIterable, Identifiable {
    case overview = "OVERVIEW"
    case sound = "SOUND"
    case control = "CONTROL"
    case devices = "DEVICES"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: "headphones"
        case .sound: "slider.vertical.3"
        case .control: "hand.tap"
        case .devices: "square.grid.2x2"
        }
    }
}

/// Full-size window: a slim rail on the left, a product hero, then a bento grid of tiles.
/// Appears in the Dock while open.
struct DashboardView: View {
    @Bindable var manager: CMFBluetoothManager
    @State private var page: DashboardPage = .overview

    var body: some View {
        HStack(spacing: 0) {
            rail
            ScrollView {
                if manager.isConnected {
                    VStack(spacing: 14) {
                        hero
                        pageContent
                    }
                    .padding(22)
                } else {
                    EmptyStateView(manager: manager)
                        .frame(maxWidth: 560)
                        .padding(28)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(minWidth: 1040, minHeight: 700)
        .background(AmbientBackground())
        .foregroundStyle(CMFTheme.ink)
        .preferredColorScheme(.dark)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear { NSApp.setActivationPolicy(.accessory) }
    }

    // MARK: Rail

    private var rail: some View {
        VStack(spacing: 0) {
            Text("NOTHING")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .tracking(4)
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(width: 64, height: 120)
                .padding(.top, 18)
            Spacer()
            VStack(spacing: 14) {
                ForEach(DashboardPage.allCases) { item in
                    Button { page = item } label: {
                        Image(systemName: item.symbol)
                            .font(.system(size: 15))
                            .foregroundStyle(page == item ? Color.black : CMFTheme.muted)
                            .frame(width: 42, height: 42)
                            .background(page == item ? Color.white : .clear, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(item.rawValue.capitalized)
                    .disabled(!manager.isConnected)
                }
            }
            Spacer()
            Circle().fill(manager.isConnected ? CMFTheme.red : CMFTheme.dim).frame(width: 7, height: 7).padding(.bottom, 24)
        }
        .frame(width: 64)
        .glass(radius: 32)
        .padding(.leading, 14)
        .padding(.vertical, 14)
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .leading) {
            DotGrid(pitch: 14, dot: 1.4, color: .white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            HStack {
                Spacer()
                DeviceArtwork(modelName: manager.artworkModelName)
                    .frame(maxWidth: 360)
                    .padding(.vertical, 12)
                    .padding(.trailing, 40)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.35)],
                                         startPoint: .leading, endPoint: .trailing))
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    chip(manager.connectionState.rawValue.uppercased(), solid: true)
                    chip(manager.isOverEar ? "HEADPHONES" : "EARBUDS", solid: false)
                }
                Text(manager.displayModelName.uppercased())
                    .font(.system(size: 50, weight: .light))
                    .tracking(-1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                HStack(spacing: 6) {
                    Circle().fill(CMFTheme.red).frame(width: 5, height: 5)
                    Text("\(manager.connectionState.rawValue) · Bluetooth")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(CMFTheme.muted)
                }
            }
            .padding(.leading, 30)
            VStack {
                HStack {
                    Spacer()
                    Text("NOTHING_X // CONTROL")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced)).tracking(1)
                        .foregroundStyle(CMFTheme.muted)
                }
                Spacer()
            }
            .padding(18)
        }
        .frame(height: 230)
        .glass(radius: 30)
    }

    private func chip(_ text: String, solid: Bool) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .bold, design: .monospaced)).tracking(0.8)
            .foregroundStyle(solid ? Color.black : CMFTheme.ink.opacity(0.8))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(solid ? CMFTheme.ink : Color.white.opacity(0.10), in: Capsule())
    }

    // MARK: Pages

    @ViewBuilder private var pageContent: some View {
        switch page {
        case .overview: overview
        case .sound:
            HStack(alignment: .top, spacing: 14) {
                SoundTab(manager: manager)
                VStack(spacing: 14) { audioMode; powerSupply }.frame(maxWidth: 360)
            }
        case .control:
            HStack(alignment: .top, spacing: 14) {
                ControlsTab(manager: manager)
                VStack(spacing: 14) { audioMode; coreSystem }.frame(maxWidth: 360)
            }
        case .devices:
            HStack(alignment: .top, spacing: 14) {
                DeviceTab(manager: manager, showsDashboardButton: false)
                VStack(spacing: 14) { powerSupply; coreSystem }.frame(maxWidth: 360)
            }
        }
    }

    private var overview: some View {
        Grid(horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
                eqProfile.gridCellColumns(2)
                powerSupply
                bassTile
            }
            GridRow {
                cells.gridCellColumns(2)
                audioMode
                coreSystem
            }
        }
    }

    // MARK: Tiles

    private var eqProfile: some View {
        NothingCard(fillsHeight: true) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "EQ_PROFILE", trailing: manager.eqPreset.rawValue)
                PillSegments(options: EQPreset.allCases.map { ($0, $0.rawValue) }, selection: manager.eqPreset) { manager.setEQ($0) }
                EQCurve(bands: manager.eqPreset == .custom ? manager.customEQ : manager.eqPreset.indicativeBands)
            }
        }
    }

    private var batteryAverage: Int? {
        guard let battery = manager.battery else { return nil }
        let values = [battery.headset, battery.left, battery.right].compactMap { $0?.percentage }
        return values.isEmpty ? nil : values.reduce(0, +) / values.count
    }

    private var powerSupply: some View {
        NothingCard(fillsHeight: true) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "POWER_SUPPLY")
                BigFigure(value: batteryAverage.map(String.init) ?? "--", unit: "%",
                          caption: manager.battery.map { [$0.headset, $0.left, $0.right].contains { $0?.isCharging == true } ? "Charging" : "Discharging" } ?? "Waiting for report")
                ThinBar(progress: Double(batteryAverage ?? 0) / 100, tint: (batteryAverage ?? 100) < 20 ? CMFTheme.red : CMFTheme.ink)
            }
        }
    }

    private var bassTile: some View {
        NothingCard(fillsHeight: true) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "BASS_ENHANCE")
                BigFigure(value: "\(manager.bassBoost)", unit: "/5", caption: "Low-end boost")
                DotSlider(value: Binding(get: { manager.bassBoost }, set: manager.setBassBoost), range: 0...5)
            }
        }
    }

    private var cells: some View {
        NothingCard(fillsHeight: true) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "BATTERY_CELLS", trailing: manager.firmwareVersion.map { "FW \($0)" })
                HStack(alignment: .top, spacing: 26) {
                    if let battery = manager.battery {
                        ForEach(Array(cellList(battery).enumerated()), id: \.offset) { _, cell in
                            VStack(alignment: .leading, spacing: 8) {
                                BigFigure(value: "\(cell.1.percentage)", unit: "%", caption: cell.0 + (cell.1.isCharging ? " · charging" : ""))
                                ThinBar(progress: Double(cell.1.percentage) / 100, tint: cell.1.percentage < 20 ? CMFTheme.red : CMFTheme.ink)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        Text(manager.batteryMessage).font(.system(size: 11)).foregroundStyle(CMFTheme.muted)
                    }
                }
            }
        }
    }

    private func cellList(_ battery: BatteryStatus) -> [(String, BatteryComponent)] {
        var result: [(String, BatteryComponent)] = []
        if let value = battery.headset { result.append(("Headset", value)) }
        if let value = battery.left { result.append(("Left", value)) }
        if let value = battery.right { result.append(("Right", value)) }
        if let value = battery.caseBattery { result.append(("Case", value)) }
        return result
    }

    private var audioMode: some View {
        NothingCard(fillsHeight: true) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "AUDIO_MODE")
                HStack(spacing: 6) {
                    Text(manager.noiseMode.rawValue.uppercased()).font(.system(size: 14, weight: .bold))
                    Circle().fill(CMFTheme.red).frame(width: 5, height: 5)
                }
                PillSegments(options: [(ANCMode.mid, "ANC"), (.transparency, "Trans"), (.off, "Off")],
                             selection: manager.noiseMode.isANC ? .mid : manager.noiseMode) { mode in
                    manager.setNoiseMode(mode == .mid && manager.noiseMode.isANC ? manager.ancIntensity : mode)
                }
                if manager.noiseMode.isANC {
                    PillSegments(options: [(ANCMode.low, "Low"), (.mid, "Mid"), (.high, "High"), (.adaptive, "Auto")],
                                 selection: manager.ancIntensity) { manager.setANCIntensity($0) }
                }
            }
        }
    }

    private var coreSystem: some View {
        NothingCard(fillsHeight: true) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "CORE_SYSTEM")
                BigFigure(value: manager.firmwareVersion ?? "--", caption: "Firmware", size: 22)
                if let serial = manager.serialNumber {
                    Text(serial).font(.system(size: 9, design: .monospaced)).foregroundStyle(CMFTheme.muted).lineLimit(1)
                }
                Button { manager.refreshBattery() } label: {
                    Text("REFRESH STATUS")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced)).tracking(0.8)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(CMFTheme.lineStrong, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
