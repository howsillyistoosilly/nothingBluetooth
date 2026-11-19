import AppKit
import SwiftUI

/// Rotary knob with a dot-matrix scale. Drag around it to turn; it clicks into whole steps with haptic feedback.
struct RotaryKnob: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var size: CGFloat = 150

    private let sweep = 270.0
    private var steps: Int { max(1, range.upperBound - range.lowerBound) }
    private var fraction: Double { Double(value - range.lowerBound) / Double(steps) }
    private var angle: Double { -sweep / 2 + sweep * fraction }

    var body: some View {
        ZStack {
            scale
            Circle()
                .fill(RadialGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.03)],
                                     center: .topLeading, startRadius: 2, endRadius: size * 0.5))
                .frame(width: size * 0.60, height: size * 0.60)
                .glass(in: Circle(), interactive: true)
                .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
            // Indicator dot riding the rim of the knob face.
            Circle()
                .fill(CMFTheme.red)
                .frame(width: size * 0.055, height: size * 0.055)
                .shadow(color: CMFTheme.red.opacity(0.8), radius: 4)
                .offset(y: -size * 0.245)
                .rotationEffect(.degrees(angle))
            DotText(text: "\(value)", dot: size * 0.017, gap: size * 0.008)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in turn(to: drag.location) })
        .animation(.smooth(duration: 0.18), value: value)
        .accessibilityElement()
        .accessibilityLabel("Bass enhance")
        .accessibilityValue("\(value) of \(range.upperBound)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(min(range.upperBound, value + 1))
            case .decrement: set(max(range.lowerBound, value - 1))
            @unknown default: break
            }
        }
    }

    /// Ring of dots, lit up to the current position.
    private var scale: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2 - 6
            let count = steps * 4 + 1
            for index in 0..<count {
                let f = Double(index) / Double(count - 1)
                let theta = (-sweep / 2 + sweep * f) * .pi / 180
                let point = CGPoint(x: center.x + radius * sin(theta), y: center.y - radius * cos(theta))
                let major = index % 4 == 0
                let lit = f <= fraction + 0.0001
                let side: CGFloat = major ? 5 : 2.6
                let color: Color = lit ? (major ? CMFTheme.red : CMFTheme.ink) : CMFTheme.ink.opacity(major ? 0.35 : 0.18)
                context.fill(Path(ellipseIn: CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)),
                             with: .color(color))
            }
        }
    }

    private func turn(to location: CGPoint) {
        let dx = location.x - size / 2
        let dy = location.y - size / 2
        guard hypot(dx, dy) > size * 0.08 else { return }
        var degrees = atan2(dx, -dy) * 180 / .pi            // 0 at the top, clockwise positive
        // The bottom dead zone snaps to the nearest end so the knob never jumps across.
        if degrees > sweep / 2 { degrees = sweep / 2 } else if degrees < -sweep / 2 { degrees = -sweep / 2 }
        let f = (degrees + sweep / 2) / sweep
        set(range.lowerBound + Int((f * Double(steps)).rounded()))
    }

    private func set(_ newValue: Int) {
        guard newValue != value else { return }
        value = newValue
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}
