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
        // The rail floats over the content (rather than sitting beside it) so the content can be pinned to the
        // window width; the left inset keeps it clear of the rail.
        ZStack(alignment: .leading) {
            ScrollView {
                if manager.isConnected {
                    VStack(spacing: 12) {
                        hero
                        pageContent
                    }
                    .padding(.leading, 84)
                    .padding(.trailing, 12)
                    .padding(.vertical, 12)
                    // Pin the content to the window width so the grid can never size itself wider than the window.
                    .containerRelativeFrame(.horizontal)
                } else {
                    EmptyStateView(manager: manager)
                        .frame(maxWidth: 560)
                        .padding(28)
                        .padding(.leading, 74)
                        .frame(maxWidth: .infinity)
                }
            }
            rail
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
        .padding(.leading, 10)
        .padding(.vertical, 12)
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
                // The largest dot size that fits the space; ViewThatFits avoids measuring with a GeometryReader.
                ViewThatFits(in: .horizontal) {
                    DotText(text: manager.displayModelName, dot: 6.6, gap: 2.9)
                    DotText(text: manager.displayModelName, dot: 5.6, gap: 2.4)
                    DotText(text: manager.displayModelName, dot: 4.6, gap: 2.0)
                    DotText(text: manager.displayModelName, dot: 3.8, gap: 1.6)
                    DotText(text: manager.displayModelName, dot: 3.0, gap: 1.3)
                    DotText(text: manager.displayModelName, dot: 2.4, gap: 1.0)
                }
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                HStack(spacing: 6) {
                    Circle().fill(CMFTheme.red).frame(width: 5, height: 5)
                    Text("\(manager.connectionState.rawValue) · Bluetooth")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(CMFTheme.muted)
                }
            }
            .padding(.leading, 30)
            .padding(.trailing, 300)
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
            HStack(alignment: .top, spacing: 12) {
                SoundTab(manager: manager)
                VStack(spacing: 12) { audioMode; cells }.frame(maxWidth: 380)
            }
        case .control:
            HStack(alignment: .top, spacing: 12) {
                ControlsTab(manager: manager)
                VStack(spacing: 12) { audioMode; coreSystem }.frame(maxWidth: 380)
            }
        case .devices:
            HStack(alignment: .top, spacing: 12) {
                DeviceTab(manager: manager, showsDashboardButton: false)
                VStack(spacing: 12) { cells; coreSystem }.frame(maxWidth: 380)
            }
        }
    }

    /// Explicit rows rather than a Grid: a Grid sizes its columns from every cell's ideal width, which let wide
    /// content push the whole page past the window.
    private var overview: some View {
        VStack(spacing: 12) {
            eqProfile
            HStack(alignment: .top, spacing: 12) {
                cells.frame(maxWidth: .infinity)
                audioMode.frame(maxWidth: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 12) {
                bassTile.frame(width: 250)
                coreSystem.frame(width: 270)
                quickSettings.frame(maxWidth: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Tiles

    private var eqBands: [Int] { manager.eqPreset == .custom ? manager.customEQ : manager.eqPreset.indicativeBands }

    /// Full-width equaliser: presets and the live curve on the left, band sliders on the right.
    private var eqProfile: some View {
        NothingCard(fillsHeight: true) {
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(title: "EQ_PROFILE", trailing: manager.eqPreset.rawValue)
                    PillSegments(options: EQPreset.allCases.map { ($0, $0.rawValue) }, selection: manager.eqPreset) { manager.setEQ($0) }
                    EQCurve(bands: eqBands)
                    HStack {
                        ForEach(["20", "100", "1K", "5K", "20K"], id: \.self) { label in
                            Text(label).font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(CMFTheme.muted).frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "BANDS", trailing: "dB")
                    HStack(alignment: .top, spacing: 6) {
                        ForEach(Array(["BASS", "MID", "TREBLE"].enumerated()), id: \.offset) { index, title in
                            BandSlider(title: title, gain: eqBands[index], isEnabled: true) { gain in
                                // Moving a band turns the current preset into the custom curve.
                                if manager.eqPreset != .custom { manager.customEQ = manager.eqPreset.indicativeBands }
                                manager.setCustomEQBand(index, gain: gain)
                            }
                        }
                    }
                }
                .frame(width: 270)
            }
        }
    }

    private var batteryAverage: Int? {
        guard let battery = manager.battery else { return nil }
        let values = [battery.headset, battery.left, battery.right].compactMap { $0?.percentage }
        return values.isEmpty ? nil : values.reduce(0, +) / values.count
    }

    /// Bass enhance as a rotary knob.
    private var bassTile: some View {
        NothingCard(fillsHeight: true) {
            VStack(spacing: 10) {
                SectionLabel(title: "BASS_ENHANCE", trailing: manager.bassBoost == 0 ? "Off" : "Level \(manager.bassBoost)")
                RotaryKnob(value: Binding(get: { manager.bassBoost }, set: manager.setBassBoost), range: 0...5, size: 168)
                    .frame(maxWidth: .infinity)
                Text("Turn to add low-end punch")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    /// Battery cells with the overall power supply figure folded in.
    private var cells: some View {
        NothingCard(fillsHeight: true) {
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(title: "BATTERY_CELLS", trailing: manager.firmwareVersion.map { "FW \($0)" })
                HStack(alignment: .top, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        BigFigure(value: batteryAverage.map(String.init) ?? "--", unit: "%",
                                  caption: manager.battery.map { [$0.headset, $0.left, $0.right].contains { $0?.isCharging == true } ? "Power supply · charging" : "Power supply" } ?? "Waiting for report",
                                  size: 56)
                        ThinBar(progress: Double(batteryAverage ?? 0) / 100, tint: (batteryAverage ?? 100) < 20 ? CMFTheme.red : CMFTheme.ink)
                    }
                    .frame(maxWidth: .infinity)
                    if let battery = manager.battery {
                        HStack(alignment: .top, spacing: 20) {
                            ForEach(Array(cellList(battery).enumerated()), id: \.offset) { _, cell in
                                VStack(alignment: .leading, spacing: 8) {
                                    BigFigure(value: "\(cell.1.percentage)", unit: "%", caption: cell.0 + (cell.1.isCharging ? " · charging" : ""), size: 30)
                                    ThinBar(progress: Double(cell.1.percentage) / 100, tint: cell.1.percentage < 20 ? CMFTheme.red : CMFTheme.ink)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity)
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
            VStack(alignment: .leading, spacing: 18) {
                SectionLabel(title: "LISTENING_MODE", trailing: manager.noiseMode.rawValue)
                NoiseModeSelector(manager: manager)
                Spacer(minLength: 0)
            }
        }
    }

    private var quickSettings: some View {
        NothingCard(fillsHeight: true) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "QUICK_SETTINGS")
                ToggleRow(title: "Spatial Audio", caption: "Surround sound",
                          isOn: Binding(get: { manager.spatialAudioEnabled }, set: manager.setSpatialAudio))
                Divider().overlay(CMFTheme.line)
                ToggleRow(title: "Low Lag Mode", caption: "Less delay for games and video",
                          isOn: Binding(get: { manager.lowLatencyEnabled }, set: manager.setLowLatency))
                Divider().overlay(CMFTheme.line)
                ToggleRow(title: manager.isOverEar ? "Auto pause" : "In-ear detection", caption: "Pause when you take them off",
                          isOn: Binding(get: { manager.inEarDetectionEnabled }, set: manager.setInEarDetection),
                          isAvailable: manager.supportsInEarDetection)
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
