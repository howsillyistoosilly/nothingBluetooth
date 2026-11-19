import SwiftUI

/// Flat grey card with the large corner radius used across Nothing X.
struct NothingCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CMFTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Small dot-matrix section label.
struct SectionLabel: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            DotText(text: title, dot: 1.9, gap: 0.9, color: CMFTheme.ink.opacity(0.85))
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(CMFTheme.muted)
            }
        }
    }
}

/// Pill segmented control; the selected segment is solid white like the Nothing X mode picker.
struct PillSegments<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    let selection: Value?
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button { onSelect(option.value) } label: {
                    Text(option.title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(selected ? Color.black : CMFTheme.ink.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selected ? Color.white : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(CMFTheme.raised, in: Capsule())
    }
}

/// Round two-state switch with a red dot, in place of the stock macOS switch.
struct NothingSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? CMFTheme.ink : CMFTheme.raised)
                Circle()
                    .fill(isOn ? CMFTheme.red : CMFTheme.muted)
                    .frame(width: 18, height: 18)
                    .padding(3)
            }
            .frame(width: 46, height: 24)
            .animation(.snappy(duration: 0.18), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// Settings row: title, caption and a switch.
struct ToggleRow: View {
    let title: String
    let caption: String
    @Binding var isOn: Bool
    var isAvailable = true

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundStyle(CMFTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            NothingSwitch(isOn: $isOn)
        }
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.4)
    }
}

/// Track of dots that fills left to right; click or drag to set the level.
struct DotSlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var accent: Color = CMFTheme.ink

    var body: some View {
        GeometryReader { proxy in
            let count = range.count
            let pitch = proxy.size.width / CGFloat(count)
            HStack(spacing: 0) {
                ForEach(range, id: \.self) { step in
                    Circle()
                        .fill(step <= value && value != range.lowerBound ? accent : CMFTheme.dim)
                        .frame(width: step == value ? 12 : 6, height: step == value ? 12 : 6)
                        .frame(width: pitch, height: proxy.size.height)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let index = Int(drag.location.x / pitch)
                let clamped = min(range.upperBound, max(range.lowerBound, range.lowerBound + index))
                if clamped != value { value = clamped }
            })
        }
        .frame(height: 22)
        .accessibilityElement()
        .accessibilityValue("\(value) of \(range.upperBound)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + 1)
            case .decrement: value = max(range.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }
}

/// Circular battery dial: a ring of dots filled to the charge level with a dot-matrix percentage inside.
struct BatteryDial: View {
    let title: String
    let component: BatteryComponent

    private let ringDots = 28

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Canvas { context, size in
                    let radius = min(size.width, size.height) / 2 - 3
                    let filled = Int((Double(component.percentage) / 100 * Double(ringDots)).rounded())
                    let lowColor = component.percentage < 20 ? CMFTheme.red : CMFTheme.ink
                    for index in 0..<ringDots {
                        let angle = -Double.pi / 2 + Double(index) / Double(ringDots) * 2 * .pi
                        let center = CGPoint(x: size.width / 2 + radius * cos(angle),
                                             y: size.height / 2 + radius * sin(angle))
                        let on = index < filled
                        let side: CGFloat = on ? 3 : 2
                        context.fill(Path(ellipseIn: CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)),
                                     with: .color(on ? lowColor : CMFTheme.dim))
                    }
                }
                VStack(spacing: 2) {
                    DotText(text: "\(component.percentage)", dot: 2, gap: 1)
                    if component.isCharging {
                        Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundStyle(CMFTheme.red)
                    }
                }
            }
            .frame(width: 66, height: 66)
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(CMFTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) battery \(component.percentage) percent\(component.isCharging ? ", charging" : "")")
    }
}

/// Small status pill used in headers.
struct StatusPill: View {
    let text: String
    let active: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(active ? CMFTheme.red : CMFTheme.muted).frame(width: 6, height: 6)
            Text(text).font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(CMFTheme.raised, in: Capsule())
    }
}
