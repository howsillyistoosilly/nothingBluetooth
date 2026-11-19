import SwiftUI

struct SoundTab: View {
    @Bindable var manager: CMFBluetoothManager
    @State private var presetName = ""

    private var displayedBands: [Int] {
        manager.eqPreset == .custom ? manager.customEQ : manager.eqPreset.indicativeBands
    }

    var body: some View {
        VStack(spacing: 12) {
            equalizer
            bassEnhance
            spatial
        }
        .disabled(!manager.isConnected)
        .opacity(manager.isConnected ? 1 : 0.5)
    }

    private var equalizer: some View {
        NothingCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "EQUALISER", trailing: manager.eqPreset.rawValue)
                EQCurve(bands: displayedBands)
                    .padding(.horizontal, 2)
                HStack(spacing: 4) {
                    ForEach(["20", "100", "1K", "5K", "20K"], id: \.self) { label in
                        Text(label)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(CMFTheme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(EQPreset.allCases) { preset in
                        let selected = manager.eqPreset == preset
                        Button { manager.setEQ(preset) } label: {
                            HStack(spacing: 7) {
                                Circle().fill(selected ? CMFTheme.red : CMFTheme.dim).frame(width: 6, height: 6)
                                Text(preset.rawValue).font(.system(size: 12, weight: .medium))
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(selected ? Color.white.opacity(0.14) : CMFTheme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if manager.eqPreset == .custom { customEditor }
            }
        }
    }

    private var customEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(CMFTheme.line)
            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(["BASS", "MID", "TREBLE"].enumerated()), id: \.offset) { index, title in
                    BandSlider(title: title, gain: manager.customEQ[index], isEnabled: true) {
                        manager.setCustomEQBand(index, gain: $0)
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("Preset name", text: $presetName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(CMFTheme.raised, in: Capsule())
                    .onSubmit(savePreset)
                Button("Save", action: savePreset)
                Button("Reset") { manager.resetCustomEQ() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            if !manager.savedEQPresets.isEmpty {
                VStack(spacing: 6) {
                    ForEach(manager.savedEQPresets) { preset in
                        HStack {
                            Button { manager.applyEQPreset(preset) } label: {
                                HStack {
                                    Text(preset.name).font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    Text(preset.bands.map { "\($0 > 0 ? "+" : "")\($0)" }.joined(separator: " "))
                                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(CMFTheme.muted)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(CMFTheme.raised, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            Button { manager.deleteEQPreset(preset) } label: {
                                Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(CMFTheme.muted)
                            }
                            .buttonStyle(.plain)
                            .help("Delete preset")
                        }
                    }
                }
            }
        }
    }

    private func savePreset() {
        manager.saveCurrentEQ(named: presetName)
        presetName = ""
    }

    private var bassEnhance: some View {
        NothingCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title: "BASS ENHANCE", trailing: "\(manager.bassBoost) / 5")
                DotSlider(value: Binding(get: { manager.bassBoost }, set: manager.setBassBoost), range: 0...5)
                Text("Adds low-end punch. Turns off Spatial Audio.")
                    .font(.system(size: 10))
                    .foregroundStyle(CMFTheme.muted)
            }
        }
    }

    private var spatial: some View {
        NothingCard {
            ToggleRow(title: "Spatial Audio",
                      caption: "Immersive surround sound. Resets EQ and Bass Enhance.",
                      isOn: Binding(get: { manager.spatialAudioEnabled }, set: manager.setSpatialAudio))
        }
    }
}
