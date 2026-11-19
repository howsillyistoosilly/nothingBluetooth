import SwiftUI

/// Indicative 3-band shapes (bass, mid, treble in dB) for each preset, used only to draw the curve.
extension EQPreset {
    var indicativeBands: [Int] {
        switch self {
        case .balanced: [0, 0, 0]
        case .moreBass: [5, 1, -1]
        case .moreTreble: [-1, 0, 5]
        case .voice: [-3, 4, 1]
        case .custom: [0, 0, 0]
        }
    }
}

/// Dot-matrix frequency response curve across 20 Hz - 20 kHz.
struct EQCurve: View {
    let bands: [Int]
    var height: CGFloat = 110
    private let columns = 36
    private let limit = 6.0

    private func gain(at position: Double) -> Double {
        EQSpline.gain(bands: bands, at: position)
    }

    var body: some View {
        Canvas { context, size in
            let rows = 13
            let rowPitch = size.height / CGFloat(rows)
            let columnPitch = size.width / CGFloat(columns)
            for column in 0..<columns {
                let position = (Double(column) + 0.5) / Double(columns)
                let level = gain(at: position)
                let x = (CGFloat(column) + 0.5) * columnPitch
                for row in 0..<rows {
                    let rowGain = Double(rows / 2 - row)
                    let y = (CGFloat(row) + 0.5) * rowPitch
                    let isCurve = abs(rowGain - level) < 0.5
                    let isZeroLine = row == rows / 2
                    let side: CGFloat = isCurve ? 4 : (isZeroLine ? 2 : 1.4)
                    let color: Color = isCurve ? CMFTheme.ink : (isZeroLine ? CMFTheme.muted : CMFTheme.dim)
                    context.fill(Path(ellipseIn: CGRect(x: x - side / 2, y: y - side / 2, width: side, height: side)),
                                 with: .color(color))
                }
            }
        }
        .frame(height: height)
        .animation(.snappy(duration: 0.25), value: bands)
        .accessibilityLabel("Equaliser curve")
        .accessibilityValue("Bass \(bands[0]), mid \(bands[1]), treble \(bands[2]) decibels")
    }
}

/// Vertical dot slider for one EQ band, -6 to +6 dB.
struct BandSlider: View {
    let title: String
    let gain: Int
    let isEnabled: Bool
    let onChange: (Int) -> Void

    private let rows = 13

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let pitch = proxy.size.height / CGFloat(rows)
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        let rowGain = rows / 2 - row
                        let active = gain >= 0 ? (rowGain >= 0 && rowGain <= gain) : (rowGain < 0 && rowGain >= gain)
                        Circle()
                            .fill(rowGain == gain ? CMFTheme.red : (active ? CMFTheme.ink : CMFTheme.dim))
                            .frame(width: rowGain == gain ? 10 : (row == rows / 2 ? 5 : 4),
                                   height: rowGain == gain ? 10 : (row == rows / 2 ? 5 : 4))
                            .frame(maxWidth: .infinity)
                            .frame(height: pitch)
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    guard isEnabled else { return }
                    let row = min(rows - 1, max(0, Int(drag.location.y / pitch)))
                    onChange(rows / 2 - row)
                })
            }
            .frame(height: 130)
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(CMFTheme.muted)
            Text("\(gain > 0 ? "+" : "")\(gain) dB")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) gain")
        .accessibilityValue("\(gain) decibels")
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment: onChange(min(6, gain + 1))
            case .decrement: onChange(max(-6, gain - 1))
            @unknown default: break
            }
        }
    }
}


/// Smooth response through the three band gains (bass, mid, treble) at fixed positions along the frequency axis.
enum EQSpline {
    static let positions: [Double] = [0.12, 0.5, 0.88]
    static let limit = 6.0

    static func gain(bands: [Int], at x: Double) -> Double {
        guard bands.count == 3 else { return 0 }
        let g = bands.map(Double.init)
        if x <= positions[0] { return g[0] }
        if x >= positions[2] { return g[2] }
        let segment = x < positions[1] ? 0 : 1
        let t = (x - positions[segment]) / (positions[segment + 1] - positions[segment])
        let eased = (1 - cos(t * .pi)) / 2
        return g[segment] + (g[segment + 1] - g[segment]) * eased
    }
}

/// Interactive equaliser graph: three draggable nodes joined by a plain line over the dot matrix.
/// Dragging a node changes that band's gain from -6 to +6 dB.
struct EQGraph: View {
    let bands: [Int]
    var height: CGFloat = 230
    var isEnabled = true
    let onChange: (Int, Int) -> Void
    @State private var active: Int?

    private let columns = 48
    private let rows = 13
    private let names = ["BASS", "MID", "TREBLE"]

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    glow(in: size)
                    dots(in: size)
                    nodes(in: size)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard isEnabled else { return }
                        if active == nil { active = nearestNode(to: drag.startLocation.x / size.width) }
                        guard let node = active else { return }
                        let level = (size.height / 2 - drag.location.y) / (size.height / 2) * EQSpline.limit
                        onChange(node, Int(max(-EQSpline.limit, min(EQSpline.limit, level)).rounded()))
                    }
                    .onEnded { _ in active = nil })
            }
            .frame(height: height)
            HStack {
                ForEach(["20", "100", "1K", "5K", "20K"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(CMFTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Equaliser graph")
        .accessibilityValue("Bass \(bands[0]), mid \(bands[1]), treble \(bands[2]) decibels")
    }

    private func nearestNode(to x: CGFloat) -> Int {
        EQSpline.positions.enumerated().min { abs($0.element - Double(x)) < abs($1.element - Double(x)) }?.offset ?? 0
    }

    private func y(forGain gain: Double, height: CGFloat) -> CGFloat {
        height / 2 - CGFloat(gain / EQSpline.limit) * (height / 2 - 14)
    }

    private func curvePoints(in size: CGSize) -> [CGPoint] {
        (0...120).map { index in
            let x = Double(index) / 120
            return CGPoint(x: CGFloat(x) * size.width, y: y(forGain: EQSpline.gain(bands: bands, at: x), height: size.height))
        }
    }

    /// A plain line through the three nodes, drawn behind the dots.
    private func glow(in size: CGSize) -> some View {
        let points = curvePoints(in: size)
        return Path { path in
            path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
        }
        .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .animation(.smooth(duration: 0.2), value: bands)
    }

    private func dots(in size: CGSize) -> some View {
        Canvas { context, canvas in
            let rowPitch = canvas.height / CGFloat(rows)
            let columnPitch = canvas.width / CGFloat(columns)
            for column in 0..<columns {
                let position = (Double(column) + 0.5) / Double(columns)
                let level = EQSpline.gain(bands: bands, at: position)
                let x = (CGFloat(column) + 0.5) * columnPitch
                for row in 0..<rows {
                    let rowGain = Double(rows / 2 - row)
                    let yy = (CGFloat(row) + 0.5) * rowPitch
                    let isCurve = abs(rowGain - level) < 0.5
                    let isZero = row == rows / 2
                    let side: CGFloat = isCurve ? 4.6 : (isZero ? 2.2 : 1.5)
                    let color: Color = isCurve ? CMFTheme.ink : (isZero ? CMFTheme.muted : CMFTheme.ink.opacity(0.18))
                    context.fill(Path(ellipseIn: CGRect(x: x - side / 2, y: yy - side / 2, width: side, height: side)), with: .color(color))
                }
            }
        }
    }

    private func nodes(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let x = CGFloat(EQSpline.positions[index]) * size.width
                let nodeY = y(forGain: Double(bands[index]), height: size.height)
                let isActive = active == index
                Circle().fill(Color.white).frame(width: isActive ? 11 : 9, height: isActive ? 11 : 9)
                    .overlay(Circle().strokeBorder(CMFTheme.red, lineWidth: 2).frame(width: isActive ? 17 : 14, height: isActive ? 17 : 14))
                    .position(x: x, y: nodeY)
                Text("\(names[index]) \(bands[index] > 0 ? "+" : "")\(bands[index]) dB")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(CMFTheme.muted)
                    .position(x: x, y: nodeY + (bands[index] >= 0 ? 18 : -18))
            }
        }
        .animation(.smooth(duration: 0.15), value: active)
    }
}
