import SwiftUI

private enum NoiseChoice: String, CaseIterable, Identifiable {
    case anc = "Noise cancel"
    case transparency = "Transparency"
    case off = "Off"
    var id: String { rawValue }

    init(_ mode: ANCMode) {
        switch mode {
        case .off: self = .off
        case .transparency: self = .transparency
        default: self = .anc
        }
    }
}

/// Listening mode as a vertical scroll selector: scroll up or down and the centred row becomes the active mode.
/// With noise cancelling on, the strength buttons (Low, Mid, High, Adaptive) appear underneath.
struct NoiseModeSelector: View {
    @Bindable var manager: CMFBluetoothManager
    @State private var position: NoiseChoice?

    private let rowHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    // Blank end rows let the first and last real row reach the centre.
                    Color.clear.frame(height: rowHeight)
                    ForEach(NoiseChoice.allCases) { choice in
                        Button { withAnimation(.smooth(duration: 0.3)) { position = choice } } label: {
                            HStack(spacing: 8) {
                                Circle().fill(CMFTheme.red).frame(width: 5, height: 5).opacity(position == choice ? 1 : 0)
                                Text(choice.rawValue).font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: rowHeight)
                            .background {
                                if position == choice {
                                    Capsule().fill(Color.white.opacity(0.16))
                                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .id(choice)
                        .scrollTransition(axis: .vertical) { content, phase in
                            content.opacity(phase.isIdentity ? 1 : 0.4).scaleEffect(phase.isIdentity ? 1 : 0.88)
                        }
                    }
                    Color.clear.frame(height: rowHeight)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position, anchor: .center)
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.2),
                                         .init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(height: rowHeight * 3 + 12)

            if manager.noiseMode.isANC {
                PillSegments(options: [(ANCMode.low, "Low"), (.mid, "Mid"), (.high, "High"), (.adaptive, "Adaptive")],
                             selection: manager.ancIntensity) { manager.setANCIntensity($0) }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.25), value: manager.noiseMode.isANC)
        .onAppear { position = NoiseChoice(manager.noiseMode) }
        .onChange(of: position) { _, new in
            guard let new, new != NoiseChoice(manager.noiseMode) else { return }
            switch new {
            case .anc: manager.setNoiseMode(manager.ancIntensity.isANC ? manager.ancIntensity : .mid)
            case .transparency: manager.setNoiseMode(.transparency)
            case .off: manager.setNoiseMode(.off)
            }
        }
        .onChange(of: manager.noiseMode) { _, mode in
            let choice = NoiseChoice(mode)
            if position != choice { withAnimation(.smooth(duration: 0.3)) { position = choice } }
        }
    }
}
