import SwiftUI

/// Paired Nothing / CMF devices; picking one switches the app's connection to it.
struct MyDevicesCard: View {
    @Bindable var manager: CMFBluetoothManager

    var body: some View {
        NothingCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "MY DEVICES", trailing: manager.isScanning ? "SCANNING" : nil)
                if manager.knownDevices.isEmpty {
                    Text("No paired Nothing or CMF devices found.")
                        .font(.system(size: 11)).foregroundStyle(CMFTheme.muted)
                }
                ForEach(manager.knownDevices) { device in
                    let current = device.address == manager.deviceAddress
                    HStack {
                        Circle().fill(current && manager.isConnected ? CMFTheme.red : CMFTheme.dim).frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            Text(current ? manager.connectionState.rawValue : (device.isConnected ? "Connected to Mac" : "Paired"))
                                .font(.system(size: 10)).foregroundStyle(CMFTheme.muted)
                        }
                        Spacer()
                        if !current {
                            Button("Switch") { manager.connect(toAddress: device.address) }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(CMFTheme.raised, in: Capsule())
                        }
                    }
                }
                let fresh = manager.discoveredDevices.filter { found in !manager.knownDevices.contains { $0.address == found.address } }
                ForEach(fresh) { device in
                    HStack {
                        Circle().fill(CMFTheme.muted).frame(width: 6, height: 6)
                        Text(device.name).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Button("Pair") { manager.pair(address: device.address) }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(CMFTheme.raised, in: Capsule())
                    }
                }
                Button {
                    manager.isScanning ? manager.stopScan() : manager.startScan()
                } label: {
                    Label(manager.isScanning ? "Stop scanning" : "Pair a new device", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
            }
        }
        .onAppear { manager.refreshKnownDevices() }
    }
}

/// Makes one or both earbuds play a tone so a lost bud can be located.
struct FindMyBudsCard: View {
    @Bindable var manager: CMFBluetoothManager

    var body: some View {
        NothingCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "FIND MY BUDS", trailing: manager.isRinging ? "RINGING" : nil)
                Text("Plays a loud tone. Take them out of your ears first.")
                    .font(.system(size: 10)).foregroundStyle(CMFTheme.muted)
                if manager.isRinging {
                    Button { manager.ring(nil, on: false) } label: {
                        Text("Stop ringing")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(CMFTheme.red, in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 6) {
                        ringButton("Left") { manager.ring(.left, on: true) }
                        ringButton("Both") { manager.ring(nil, on: true) }
                        ringButton("Right") { manager.ring(.right, on: true) }
                    }
                }
            }
        }
    }

    private func ringButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(CMFTheme.raised, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
