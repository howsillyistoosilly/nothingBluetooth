import SwiftUI

/// Full-window circular radar in dots: concentric rings that run off the edges, a sweep that rotates with a fading
/// trail, an expanding ping from the centre, and a blip for each device found that flashes as the sweep passes it.
struct RadarScanner: View {
    var active: Bool
    var blips = 0

    private let rings = 8
    private let period = 3.2            // seconds per sweep

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height * 0.44)
                // Reach the farthest corner so the rings and the sweep cover the whole window.
                let radius = hypot(max(center.x, size.width - center.x), max(center.y, size.height - center.y))
                let sweep = active ? (time.truncatingRemainder(dividingBy: period)) / period * 2 * .pi : -.pi / 4

                // Dotted rings, brighter just behind the sweep.
                for ring in 1...rings {
                    let r = radius * CGFloat(ring) / CGFloat(rings)
                    let count = max(16, Int(2 * .pi * r / 11))
                    for index in 0..<count {
                        let angle = 2 * .pi * Double(index) / Double(count)
                        let behind = (sweep - angle).truncatingRemainder(dividingBy: 2 * .pi)
                        let delta = behind < 0 ? behind + 2 * .pi : behind          // 0 at the sweep, growing behind it
                        let glow = active ? max(0, 1 - delta / 1.9) : 0
                        let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                        let side: CGFloat = 1.5 + CGFloat(glow) * 2.6
                        let color = glow > 0.04 ? CMFTheme.red.opacity(0.25 + glow * 0.75) : Color.white.opacity(0.13)
                        context.fill(Path(ellipseIn: CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)),
                                     with: .color(color))
                    }
                }

                // Cross hairs.
                for angle in stride(from: 0.0, to: 2 * Double.pi, by: .pi / 2) {
                    var line = Path()
                    line.move(to: center)
                    line.addLine(to: CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
                    context.stroke(line, with: .color(.white.opacity(0.06)), lineWidth: 1)
                }

                guard active else {
                    context.fill(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)), with: .color(CMFTheme.muted))
                    return
                }

                // Sweep wedge: a red leading edge with a trail fading behind it.
                var trail = Path()
                trail.move(to: center)
                trail.addArc(center: center, radius: radius, startAngle: .radians(sweep - 1.1), endAngle: .radians(sweep), clockwise: false)
                trail.closeSubpath()
                context.fill(trail, with: .radialGradient(Gradient(colors: [CMFTheme.red.opacity(0.0), CMFTheme.red.opacity(0.28)]),
                                                            center: center, startRadius: 0, endRadius: radius))
                var edge = Path()
                edge.move(to: center)
                edge.addLine(to: CGPoint(x: center.x + radius * cos(sweep), y: center.y + radius * sin(sweep)))
                context.stroke(edge, with: .color(CMFTheme.red), lineWidth: 1.6)

                // Ping expanding from the centre.
                let ping = (time.truncatingRemainder(dividingBy: 2.4)) / 2.4
                let pingRadius = radius * CGFloat(ping)
                context.stroke(Path(ellipseIn: CGRect(x: center.x - pingRadius, y: center.y - pingRadius, width: pingRadius * 2, height: pingRadius * 2)),
                               with: .color(CMFTheme.red.opacity(0.5 * (1 - ping))), lineWidth: 1.2)

                // Blips for found devices, flashing as the sweep passes.
                for index in 0..<blips {
                    let angle = Double(index) * 2.399 + 0.7                         // golden-angle spread
                    let r = radius * CGFloat(0.35 + 0.5 * (Double((index * 7) % 5) / 5))
                    let behind = (sweep - angle).truncatingRemainder(dividingBy: 2 * .pi)
                    let delta = behind < 0 ? behind + 2 * .pi : behind
                    let flash = max(0, 1 - delta / 2.4)
                    let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                    let side = 5 + CGFloat(flash) * 5
                    context.fill(Path(ellipseIn: CGRect(x: point.x - side * 1.6, y: point.y - side * 1.6, width: side * 3.2, height: side * 3.2)),
                                 with: .color(CMFTheme.red.opacity(0.18 * flash)))
                    context.fill(Path(ellipseIn: CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)),
                                 with: .color(.white.opacity(0.35 + 0.65 * flash)))
                }

                context.fill(Path(ellipseIn: CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7, height: 7)), with: .color(CMFTheme.red))
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
        ZStack {
            RadarScanner(active: busy, blips: manager.knownDevices.count + manager.discoveredDevices.count)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer()
                titleBlock
                Spacer()
                VStack(spacing: 12) {
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
                .frame(maxWidth: 480)
            }
            .padding(20)
        }
        .onAppear {
            joke = Self.jokes.randomElement() ?? Self.jokes[0]
            manager.refreshKnownDevices()
            manager.startScan()
        }
        .onDisappear { manager.stopScan() }
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            DotText(text: busy ? (manager.connectionState == .connecting ? "CONNECTING" : "SCANNING") : "NOTHING HERE",
                    dot: 2.8, gap: 1.3)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(joke)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.72), in: Capsule())
        }
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
