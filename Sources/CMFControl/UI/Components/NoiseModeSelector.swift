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

/// Listening mode as a scrollable selector: scroll sideways and the centred item becomes the active mode.
/// With noise cancelling on, the strength buttons appear underneath.
struct NoiseModeSelector: View {
    @Bindable var manager: CMFBluetoothManager
    @State private var position: NoiseChoice?

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Blank end items let the first and last real item reach the centre.
                    Color.clear.frame(height: 1).containerRelativeFrame(.horizontal, count: 3, spacing: 10)
                    ForEach(NoiseChoice.allCases) { choice in
                        Button { withAnimation(.smooth(duration: 0.3)) { position = choice } } label: {
                            Text(choice.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background {
                                    if position == choice {
                                        Capsule().fill(Color.white.opacity(0.16))
                                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                                    }
                                }
                                .overlay(alignment: .bottom) {
                                    Circle().fill(CMFTheme.red).frame(width: 4, height: 4)
                                        .opacity(position == choice ? 1 : 0).offset(y: 7)
                                }
                        }
                        .buttonStyle(.plain)
                        .containerRelativeFrame(.horizontal, count: 3, spacing: 10)
                        .id(choice)
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content.opacity(phase.isIdentity ? 1 : 0.4).scaleEffect(phase.isIdentity ? 1 : 0.86)
                        }
                    }
                    Color.clear.frame(height: 1).containerRelativeFrame(.horizontal, count: 3, spacing: 10)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position, anchor: .center)
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                                         .init(color: .black, location: 0.88), .init(color: .clear, location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
            // A horizontal scroll view reports its whole content width as its ideal width, which made grids size
            // their columns far too wide; give it a small ideal width and let it flex to whatever it is offered.
            .frame(minWidth: 0, idealWidth: 120, maxWidth: .infinity)
            .frame(height: 56)

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
