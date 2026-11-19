import SwiftUI

/// Dot field with CRT-style scanlines and a bright bar sweeping down it, shown while looking for devices.
struct ScanlineField: View {
    var active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let sweep = active ? (time.truncatingRemainder(dividingBy: 2.6)) / 2.6 : 0.5
                let barY = sweep * size.height

                let pitch: CGFloat = 11
                var y = pitch / 2
                while y < size.height {
                    var x = pitch / 2
                    while x < size.width {
                        let distance = abs(y - barY)
                        let glow = active ? max(0, 1 - distance / 70) : 0
                        let side = 1.6 + glow * 2.6
                        let color = glow > 0.05 ? CMFTheme.red.opacity(0.25 + glow * 0.75) : Color.white.opacity(0.12)
                        context.fill(Path(ellipseIn: CGRect(x: x - side / 2, y: y - side / 2, width: side, height: side)),
                                     with: .color(color))
                        x += pitch
                    }
                    y += pitch
                }

                // Static scanlines.
                var lineY: CGFloat = 0
                while lineY < size.height {
                    context.fill(Path(CGRect(x: 0, y: lineY, width: size.width, height: 1)), with: .color(.black.opacity(0.35)))
                    lineY += 3
                }

                // The sweeping bar with a fading trail above it.
                if active {
                    let trail = CGRect(x: 0, y: barY - 60, width: size.width, height: 60)
                    context.fill(Path(trail), with: .linearGradient(
                        Gradient(colors: [.clear, CMFTheme.red.opacity(0.22)]),
                        startPoint: CGPoint(x: 0, y: trail.minY), endPoint: CGPoint(x: 0, y: trail.maxY)))
                    context.fill(Path(CGRect(x: 0, y: barY - 1, width: size.width, height: 2)), with: .color(CMFTheme.red))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Shown whenever no device is connected: joke, radar, and the paired / nearby device lists.
struct EmptyStateView: View {
    @Bindable var manager: CMFBluetoothManager

    private static let jokes = [
        "there's nothing to connect. ahaha. get it?",
        "nothing here. get it? it's the brand name. ahaha.",
        "we looked everywhere and found nothing. on brand."
    ]
    @State private var joke = EmptyStateView.jokes[0]

    private var busy: Bool { manager.isScanning || manager.connectionState == .connecting }

    var body: some View {
        VStack(spacing: 12) {
            radar
            deviceLists
            NothingCard {
                HStack {
                    Button { manager.isScanning ? manager.stopScan() : manager.startScan() } label: {
                        Label(manager.isScanning ? "Stop scanning" : "Scan for devices", systemImage: "dot.radiowaves.left.and.right")
                    }
                    Spacer()
                    Button("Try demo mode") { manager.isMockMode = true }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
            }
        }
        .onAppear {
            joke = Self.jokes.randomElement() ?? Self.jokes[0]
            manager.refreshKnownDevices()
            manager.startScan()
        }
        .onDisappear { manager.stopScan() }
    }

    private var radar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(CMFTheme.surface)
            ScanlineField(active: busy)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            VStack(spacing: 14) {
                DotText(text: busy ? (manager.connectionState == .connecting ? "CONNECTING" : "SCANNING") : "NOTHING HERE",
                        dot: 2.6, gap: 1.2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(joke)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.78), in: Capsule())
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 250)
    }

    @ViewBuilder private var deviceLists: some View {
        if !manager.knownDevices.isEmpty || !manager.discoveredDevices.isEmpty {
            NothingCard {
                VStack(alignment: .leading, spacing: 12) {
                    if !manager.knownDevices.isEmpty {
                        SectionLabel(title: "PAIRED")
                        ForEach(manager.knownDevices) { device in
                            deviceRow(device, action: "Connect") { manager.connect(toAddress: device.address) }
                        }
                    }
                    let fresh = manager.discoveredDevices.filter { found in !manager.knownDevices.contains { $0.address == found.address } }
                    if !fresh.isEmpty {
                        SectionLabel(title: "NEARBY")
                        ForEach(fresh) { device in
                            deviceRow(device, action: "Pair") { manager.pair(address: device.address) }
                        }
                    }
                }
            }
        }
    }

    private func deviceRow(_ device: KnownDevice, action: String, perform: @escaping () -> Void) -> some View {
        HStack {
            Circle().fill(device.isConnected ? CMFTheme.red : CMFTheme.dim).frame(width: 6, height: 6)
            Text(device.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
            Spacer()
            Button(action, action: perform)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(CMFTheme.raised, in: Capsule())
        }
    }
}
