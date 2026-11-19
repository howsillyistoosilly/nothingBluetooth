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

/// Full-size window: a slim rail on the left, the device on top, then a bento grid of tiles.
/// Appears in the Dock while open.
struct DashboardView: View {
    @Bindable var manager: CMFBluetoothManager
    @State private var page: DashboardPage
    @State private var presetName = ""

    init(manager: CMFBluetoothManager, initialPage: Int = 0) {
        self.manager = manager
        _page = State(initialValue: DashboardPage.allCases[initialPage])
    }

    var body: some View {
        // The rail floats over the content (rather than sitting beside it) so the content can be pinned to the
        // window width; the left inset keeps it clear of the rail.
        ZStack(alignment: .leading) {
            if manager.isConnected {
                // One frame, no scrolling: the layout stretches with the window and the equaliser absorbs the extra height.
                VStack(spacing: 14) {
                    if page == .overview { hero }
                    pageContent
                }
                .padding(.leading, 96)
                .padding(.trailing, 24)
                .padding(.top, 30)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                rail.transition(.opacity.combined(with: .move(edge: .leading)))
            } else {
                // Until something connects the window is just the radar on black.
                EmptyStateView(manager: manager)
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
            }
        }
        .animation(.smooth(duration: 0.8), value: manager.isConnected)
        .clipped()
        .frame(minWidth: 1000, minHeight: 720)
        .background(AmbientBackground(revealed: manager.isConnected))
        .background(WindowConfigurator())
        .foregroundStyle(CMFTheme.ink)
        .preferredColorScheme(.dark)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
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
        .padding(.top, 42)
        .padding(.bottom, 12)
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .leading) {
            DotGrid(pitch: 14, dot: 1.4, color: .white.opacity(0.07))
            // A big close-up of the product, cropped by the card and bleeding off the right edge.
            HStack {
                Spacer()
                DeviceArtwork(modelName: manager.artworkModelName)
                    .frame(width: 560, height: 420)
                    .scaleEffect(1.3)
                    .offset(x: 90, y: 26)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.3)],
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
            .padding(.trailing, 420)
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
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
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

    /// Each page shows only what belongs to it; the overview is the one place with the device, battery and listening mode.
    @ViewBuilder private var pageContent: some View {
        switch page {
        case .overview: overview
        case .sound: soundPage
        case .control: ControlsTab(manager: manager, wide: true).frame(maxHeight: .infinity, alignment: .top)
        case .devices: DeviceTab(manager: manager, showsDashboardButton: false, wide: true).frame(maxHeight: .infinity, alignment: .top)
        }
    }

    /// Sound: the equaliser with its graph filling the height, then saved presets and Spatial Audio beside it.
    private var soundPage: some View {
        HStack(alignment: .top, spacing: 14) {
            NothingCard(fillsHeight: true) {
                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(title: "EQUALISER", trailing: manager.eqPreset.rawValue)
                    PillSegments(options: EQPreset.allCases.map { ($0, $0.rawValue) }, selection: manager.eqPreset) { manager.setEQ($0) }
                    EQGraph(bands: eqBands, height: nil) { index, gain in manager.editEQBand(index, gain: gain) }
                    HStack(spacing: 8) {
                        TextField("Preset name", text: $presetName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(CMFTheme.raised, in: Capsule())
                            .onSubmit(savePreset)
                        Button("Save", action: savePreset)
                        Button("Reset") { manager.resetCustomEQ() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                }
            }
            VStack(spacing: 14) {
                NothingCard(fillsHeight: true) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(title: "SAVED_PRESETS", trailing: "\(manager.savedEQPresets.count)")
                        if manager.savedEQPresets.isEmpty {
                            Text("Move the points on the graph, name the curve and save it here.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        ForEach(manager.savedEQPresets.prefix(6)) { preset in
                            HStack {
                                Button { manager.applyEQPreset(preset) } label: {
                                    HStack {
                                        Text(preset.name).font(.system(size: 12, weight: .medium))
                                        Spacer()
                                        Text(preset.bands.map { "\($0 > 0 ? "+" : "")\($0)" }.joined(separator: " "))
                                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(CMFTheme.muted)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(CMFTheme.raised, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                Button { manager.deleteEQPreset(preset) } label: {
                                    Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(CMFTheme.muted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                NothingCard {
                    ToggleRow(title: "Spatial Audio", caption: "Immersive surround sound. Resets EQ and Bass Enhance.",
                              isOn: Binding(get: { manager.spatialAudioEnabled }, set: manager.setSpatialAudio))
                }
            }
            .frame(width: 340)
        }
        .frame(maxHeight: .infinity)
    }

    private func savePreset() {
        manager.saveCurrentEQ(named: presetName)
        presetName = ""
    }

    /// The equaliser presets across the top, then battery (two parts), listening mode and bass enhance.
    private var overview: some View {
        VStack(spacing: 14) {
            eqProfile.frame(maxHeight: .infinity)
            WeightedRow(weights: [2, 1, 1], spacing: 14) {
                cells
                audioMode
                bassTile
            }
        }
    }

    // MARK: Tiles

    private var eqBands: [Int] { manager.eqPreset == .custom ? manager.customEQ : manager.eqPreset.indicativeBands }

    /// Presets across the top. The read-only curve shows the chosen preset; choosing Custom swaps it for the
    /// editable graph.
    private var eqProfile: some View {
        NothingCard(fillsHeight: true) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "EQ_PROFILE", trailing: manager.eqPreset.rawValue)
                PillSegments(options: EQPreset.allCases.map { ($0, $0.rawValue) }, selection: manager.eqPreset) { manager.setEQ($0) }
                if manager.eqPreset == .custom {
                    EQGraph(bands: eqBands, height: nil) { index, gain in manager.editEQBand(index, gain: gain) }
                } else {
                    EQCurve(bands: eqBands, height: nil)
                    HStack {
                        ForEach(["20", "100", "1K", "5K", "20K"], id: \.self) { label in
                            Text(label).font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(CMFTheme.muted).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var batteryAverage: Int? {
        guard let battery = manager.battery else { return nil }
        let values = [battery.headset, battery.left, battery.right].compactMap { $0?.percentage }
        return values.isEmpty ? nil : values.reduce(0, +) / values.count
    }

    /// Bass enhance as a rotary knob: drag around it to turn, and it clicks into the six levels.
    private var bassTile: some View {
        NothingCard(fillsHeight: true) {
            VStack(spacing: 10) {
                SectionLabel(title: "BASS_ENHANCE", trailing: manager.bassBoost == 0 ? "Off" : "Level \(manager.bassBoost)")
                RotaryKnob(value: Binding(get: { manager.bassBoost }, set: manager.setBassBoost), range: 0...5, size: 156)
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
                SectionLabel(title: "BATTERY_CELLS")
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


/// Removes the grey title bar: the window's top is transparent so the content runs to the edge, with the
/// traffic-light buttons floating over it, and the window can be dragged from any empty area.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { Self.configure(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { Self.configure(view.window) }
    }

    private static func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
    }
}
