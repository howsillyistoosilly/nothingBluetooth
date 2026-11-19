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
    private let columns = 36
    private let limit = 6.0

    private func gain(at position: Double) -> Double {
        let centers = [0.12, 0.5, 0.88]
        var total = 0.0
        for (index, center) in centers.enumerated() where bands.indices.contains(index) {
            let distance = (position - center) / 0.24
            total += Double(bands[index]) * exp(-distance * distance)
        }
        return max(-limit, min(limit, total))
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
        .frame(height: 110)
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
