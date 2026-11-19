import SwiftUI

/// Per-earbud press and hold actions, including which noise modes the noise-control press cycles through.
struct GestureCard: View {
    @Bindable var manager: CMFBluetoothManager
    @State private var side: EarSide = .left

    private var slots: [GestureSlot] {
        manager.gestures.keys.filter { $0.side == side }.sorted()
    }

    var body: some View {
        NothingCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionLabel(title: "GESTURES")
                    Button { manager.refreshGestures() } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("Read gestures from the device")
                }
                PillSegments(options: EarSide.allCases.map { ($0, $0.title) }, selection: side) { side = $0 }
                if slots.isEmpty {
                    Text("The device has not reported any gestures yet. Tap refresh; if it stays empty, this model may not support them.")
                        .font(.system(size: 11)).foregroundStyle(CMFTheme.muted)
                }
                ForEach(slots, id: \.code) { slot in
                    row(slot)
                    if slot != slots.last { Divider().overlay(CMFTheme.line) }
                }
            }
        }
        .onAppear { if manager.gestures.isEmpty { manager.refreshGestures() } }
    }

    /// Noise-control variants share one menu entry; the cycle toggles below pick the exact variant.
    private func menuCode(_ code: UInt8) -> UInt8 {
        GestureAction(rawValue: code)?.isNoiseControl == true ? GestureAction.noiseControl.rawValue : code
    }

    private func row(_ slot: GestureSlot) -> some View {
        let code = manager.gestures[slot] ?? GestureAction.none.rawValue
        let known = GestureAction(rawValue: code)
        var options = slot.allowedActions.map { $0.isNoiseControl ? GestureAction.noiseControl : $0 }
        var seen = Set<UInt8>()
        options = options.filter { seen.insert($0.rawValue).inserted }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(slot.title).font(.system(size: 13, weight: .medium))
                Spacer()
                Picker("", selection: Binding(
                    get: { menuCode(code) },
                    set: { manager.setGesture(slot, actionCode: $0) }
                )) {
                    ForEach(options) { Text($0.title).tag($0.rawValue) }
                    if known == nil { Text("Action \(code)").tag(code) }
                }
                .labelsHidden()
                .frame(width: 170)
            }
            if let known, known.isNoiseControl { cycle(slot, known) }
        }
    }

    private func cycle(_ slot: GestureSlot, _ action: GestureAction) -> some View {
        let state = action.cycle
        func toggle(_ title: String, _ isOn: Bool, _ update: @escaping (inout (anc: Bool, transparency: Bool, off: Bool)) -> Void) -> some View {
            Button {
                var next = state
                update(&next)
                // Cycling needs at least two modes.
                guard [next.anc, next.transparency, next.off].filter({ $0 }).count >= 2 else { return }
                manager.setGesture(slot, actionCode: GestureAction.noise(anc: next.anc, transparency: next.transparency, off: next.off).rawValue)
            } label: {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isOn ? Color.black : CMFTheme.ink.opacity(0.75))
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .background(isOn ? Color.white : CMFTheme.raised, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        return HStack(spacing: 6) {
            toggle("Noise cancel", state.anc) { $0.anc.toggle() }
            toggle("Transparency", state.transparency) { $0.transparency.toggle() }
            toggle("Off", state.off) { $0.off.toggle() }
        }
    }
}
