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

/// Full-size window: a slim rail on the left and a bento grid of tiles.
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
            .scrollBounceBehavior(.basedOnSize)
            rail
        }
        .clipped()
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

    /// The older bento layout: the equaliser across the top, then battery (two parts), listening mode and bass enhance.
    private var overview: some View {
        VStack(spacing: 12) {
            eqProfile
            WeightedRow(weights: [2, 1, 1], spacing: 12) {
                cells
                audioMode
                bassTile
            }
        }
    }

    // MARK: Tiles

    private var eqBands: [Int] { manager.eqPreset == .custom ? manager.customEQ : manager.eqPreset.indicativeBands }

    /// Full-width equaliser: the model name in the dot font, presets, and a graph whose nodes you drag.
    private var eqProfile: some View {
        NothingCard(fillsHeight: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    ViewThatFits(in: .horizontal) {
                        DotText(text: manager.displayModelName, dot: 2.6, gap: 1.2)
                        DotText(text: manager.displayModelName, dot: 2.0, gap: 0.9)
                        DotText(text: manager.displayModelName, dot: 1.5, gap: 0.7)
                    }
                    Spacer(minLength: 12)
                    Text(manager.eqPreset.rawValue)
                        .font(.system(size: 11)).foregroundStyle(CMFTheme.muted)
                }
                PillSegments(options: EQPreset.allCases.map { ($0, $0.rawValue) }, selection: manager.eqPreset) { manager.setEQ($0) }
                EQGraph(bands: eqBands, height: 280) { index, gain in manager.editEQBand(index, gain: gain) }
            }
        }
    }

    private var batteryAverage: Int? {
        guard let battery = manager.battery else { return nil }
        let values = [battery.headset, battery.left, battery.right].compactMap { $0?.percentage }
        return values.isEmpty ? nil : values.reduce(0, +) / values.count
    }

    private var bassTile: some View {
        NothingCard(fillsHeight: true) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "BASS_ENHANCE")
                BigFigure(value: "\(manager.bassBoost)", unit: "/5", caption: "Low-end boost")
                DotSlider(value: Binding(get: { manager.bassBoost }, set: manager.setBassBoost), range: 0...5)
                Spacer(minLength: 0)
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


/// Lays children out in a row with widths proportional to `weights`, all sharing the tallest child's height.
struct WeightedRow: Layout {
    var weights: [CGFloat]
    var spacing: CGFloat = 12

    private func widths(for total: CGFloat, count: Int) -> [CGFloat] {
        let w = Array(weights.prefix(count)) + Array(repeating: 1, count: max(0, count - weights.count))
        let available = max(0, total - spacing * CGFloat(count - 1))
        let sum = w.reduce(0, +)
        return w.map { available * $0 / sum }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? 900
        let columns = widths(for: total, count: subviews.count)
        let height = zip(subviews, columns).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }.max() ?? 0
        return CGSize(width: total, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = widths(for: bounds.width, count: subviews.count)
        let height = zip(subviews, columns).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }.max() ?? 0
        var x = bounds.minX
        for (subview, width) in zip(subviews, columns) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(width: width, height: height))
            x += width + spacing
        }
    }
}
