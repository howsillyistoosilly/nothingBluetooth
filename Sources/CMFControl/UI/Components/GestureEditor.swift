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
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(title: "GESTURES")
                    Button { manager.refreshGestures() } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Read gestures from the device")
                }
                PillSegments(options: EarSide.allCases.map { ($0, $0.title) }, selection: side) { side = $0 }
                if slots.isEmpty {
                    Text("The device has not reported any gestures yet. Choose refresh; if it stays empty, this model may not support them.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    ForEach(slots, id: \.code) { slot in
                        row(slot)
                        if slot != slots.last { Divider().overlay(CMFTheme.line) }
                    }
                }
            }
        }
        .onAppear { if manager.gestures.isEmpty { manager.refreshGestures() } }
    }

    /// Noise-control variants share one menu entry; the cycle toggles below pick the exact variant.
    private func menuCode(_ code: UInt8) -> UInt8 {
        GestureAction(rawValue: code)?.isNoiseControl == true ? GestureAction.noiseControl.rawValue : code
    }

    private func options(for slot: GestureSlot) -> [GestureAction] {
        var seen = Set<UInt8>()
        return slot.allowedActions
            .map { $0.isNoiseControl ? GestureAction.noiseControl : $0 }
            .filter { seen.insert($0.rawValue).inserted }
    }

    private func row(_ slot: GestureSlot) -> some View {
        let code = manager.gestures[slot] ?? GestureAction.none.rawValue
        let known = GestureAction(rawValue: code)
        let current = menuCode(code)
        let currentTitle = known.map { $0.isNoiseControl ? GestureAction.noiseControl.title : $0.title } ?? "Action \(code)"
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(slot.title).font(.system(size: 13))
                Spacer(minLength: 12)
                // System Settings style: the value reads as plain text with a chevron and opens a native menu.
                Menu {
                    ForEach(options(for: slot)) { action in
                        Button {
                            manager.setGesture(slot, actionCode: action.rawValue)
                        } label: {
                            if action.rawValue == current { Label(action.title, systemImage: "checkmark") } else { Text(action.title) }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(currentTitle).foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .font(.system(size: 13))
                    .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(.vertical, 8)
            if let known, known.isNoiseControl { cycle(slot, known).padding(.bottom, 8) }
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
                HStack(spacing: 5) {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundStyle(isOn ? CMFTheme.red : Color.secondary)
                    Text(title).font(.system(size: 12))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
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
