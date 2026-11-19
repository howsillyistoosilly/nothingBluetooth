import AppKit
import IOBluetooth
import Observation

enum BluetoothConnectionState: String {
    case disconnected = "Disconnected"
    case discovering = "Looking for headphones"
    case connecting = "Connecting"
    case connected = "Connected"
    case mock = "Demo mode"
}

struct PacketLogEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let direction: String
    let bytes: [UInt8]
    var hex: String { bytes.hexString }
}

struct SavedEQPreset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var bands: [Int]
}

struct KnownDevice: Identifiable, Equatable {
    let address: String
    let name: String
    let isConnected: Bool
    let isPaired: Bool
    var id: String { address }
}

/// How the menu bar item summarises battery.
enum BatteryDisplayMode: String, CaseIterable, Identifiable {
    case leftRight = "L·R"
    case average = "AVG"
    case minimum = "MIN"
    var id: String { rawValue }
}

@Observable @MainActor
final class CMFBluetoothManager: NSObject {
    private(set) var deviceName = "No headphones found"
    private(set) var connectionState: BluetoothConnectionState = .discovering
    private(set) var battery: BatteryStatus?
    private(set) var batteryLastUpdated: Date?
    private(set) var firmwareVersion: String?
    private(set) var deviceModel: String?
    private(set) var packetLog: [PacketLogEntry] = []
    private(set) var lastError: String?

    var isMockMode = false {
        didSet { updateMockMode() }
    }
    var noiseMode: ANCMode = .off
    var ancIntensity: ANCMode = .mid
    var eqPreset: EQPreset = .balanced
    var bassBoost = 0
    var lowLatencyEnabled = false
    var spatialAudioEnabled = false
    var dualConnectionEnabled = false
    var inEarDetectionEnabled = true
    /// Custom EQ bands (bass, mid, treble) in dB, written to the device a moment after the last change.
    var customEQ: [Int] = [0, 0, 0]
    private(set) var serialNumber: String?
    private(set) var deviceAddress: String?
    private(set) var gestures: [GestureSlot: UInt8] = [:]
    private(set) var isRinging = false
    private(set) var knownDevices: [KnownDevice] = []
    private(set) var discoveredDevices: [KnownDevice] = []
    private(set) var isScanning = false
    var savedEQPresets: [SavedEQPreset] = [] {
        didSet { saveEQPresets() }
    }
    var batteryDisplay: BatteryDisplayMode = .leftRight {
        didSet { UserDefaults.standard.set(batteryDisplay.rawValue, forKey: "cmf.batteryDisplay") }
    }

    @ObservationIgnored private let profile = CMFDeviceProfile.nothingEarFamily
    @ObservationIgnored private var bridge: CMFBluetoothBridge!
    @ObservationIgnored private var selectedDevice: IOBluetoothDevice?
    @ObservationIgnored private var channel: IOBluetoothRFCOMMChannel?
    @ObservationIgnored private var connectNotification: IOBluetoothUserNotification?
    @ObservationIgnored private var disconnectNotification: IOBluetoothUserNotification?
    @ObservationIgnored private var sequence: UInt8 = 0
    @ObservationIgnored private var parser = NothingPacketParser()
    @ObservationIgnored private var pendingWriteBuffers: [UInt: UnsafeMutableRawPointer] = [:]
    @ObservationIgnored private var outboundFrames: [[UInt8]] = []
    @ObservationIgnored private var writeInFlight = false
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var initialSyncTask: Task<Void, Never>?
    @ObservationIgnored private var batteryQueryTask: Task<Void, Never>?
    @ObservationIgnored private var waitingForDeviceInfo = false
    @ObservationIgnored private var inquiry: IOBluetoothDeviceInquiry?
    @ObservationIgnored private var pairing: IOBluetoothDevicePair?
    @ObservationIgnored private var customEQTask: Task<Void, Never>?
    @ObservationIgnored private var ringTask: Task<Void, Never>?
    @ObservationIgnored private var channelCandidates: [BluetoothRFCOMMChannelID] = []
    @ObservationIgnored private var channelProbeTask: Task<Void, Never>?
    @ObservationIgnored private var receivedNothingFrame = false
    @ObservationIgnored private var connectionAttempt = 0
    @ObservationIgnored private var channelOpenRetries = 0
    @ObservationIgnored private var reconnectFailures = 0
    @ObservationIgnored private var isSleeping = false
    @ObservationIgnored private var healTask: Task<Void, Never>?

    override init() {
        super.init()
        bridge = CMFBluetoothBridge()
        bridge.onConnected = { [weak self] device in
            Task { @MainActor in self?.consider(device) }
        }
        bridge.onDisconnected = { [weak self] device in
            Task { @MainActor in self?.deviceDisconnected(device) }
        }
        bridge.onSDPComplete = { [weak self] device, status in
            Task { @MainActor in self?.sdpCompleted(device, status: status) }
        }
        bridge.onChannelOpen = { [weak self] openedChannel, status in
            Task { @MainActor in self?.channelOpened(openedChannel, status: status) }
        }
        bridge.onChannelClose = { [weak self] closedChannel in
            Task { @MainActor in self?.channelClosed(closedChannel) }
        }
        bridge.onData = { [weak self] data in
            Task { @MainActor in self?.receive(data) }
        }
        bridge.onWriteComplete = { [weak self] refcon, status in
            Task { @MainActor in self?.writeCompleted(refcon, status: status) }
        }
        bridge.onInquiryFound = { [weak self] device in
            Task { @MainActor in self?.inquiryFound(device) }
        }
        bridge.onInquiryComplete = { [weak self] in
            Task { @MainActor in self?.isScanning = false }
        }
        bridge.onPairingFinished = { [weak self] error in
            Task { @MainActor in self?.pairingFinished(error) }
        }
        if let raw = UserDefaults.standard.string(forKey: "cmf.batteryDisplay"), let mode = BatteryDisplayMode(rawValue: raw) {
            batteryDisplay = mode
        }
        if let data = UserDefaults.standard.data(forKey: "cmf.eqPresets"),
           let presets = try? JSONDecoder().decode([SavedEQPreset].self, from: data) {
            savedEQPresets = presets
        }
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: bridge,
                                                          selector: #selector(CMFBluetoothBridge.deviceConnected(_:device:)))
        scanPairedDevices()

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.systemWillSleep() }
        }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.systemDidWake() }
        }
        // A device can refuse the control channel for a while (the phone app may hold it) and free it later.
        healTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !self.isMockMode, !self.isSleeping, self.connectionState == .disconnected,
                      let device = self.selectedDevice, device.isConnected() else { continue }
                self.consider(device)
            }
        }
    }

    /// Short battery summary for the menu bar item, per the chosen display mode.
    var menuBarBatteryText: String? {
        guard let battery, isConnected else { return nil }
        if let left = battery.left?.percentage, let right = battery.right?.percentage {
            switch batteryDisplay {
            case .leftRight: return "\(left)·\(right)"
            case .average: return "\((left + right) / 2)%"
            case .minimum: return "\(min(left, right))%"
            }
        }
        if let single = battery.headset?.percentage ?? battery.left?.percentage ?? battery.right?.percentage {
            return "\(single)%"
        }
        return nil
    }

    /// Left / right / single readings for the menu bar item.
    var menuBarReadings: (left: Int?, right: Int?, single: Int?) {
        guard let battery, isConnected else { return (nil, nil, nil) }
        return (battery.left?.percentage, battery.right?.percentage, battery.headset?.percentage)
    }

    var isConnected: Bool { connectionState == .connected || connectionState == .mock }
    var canControlHardware: Bool { isMockMode || !profile.commandIDs.isEmpty }
    var supportsInEarDetection: Bool { profile.commandIDs[.inEarSet] != nil }
    var isOverEar: Bool { displayModelName.lowercased().contains("headphone") }
    var supportsDualConnection: Bool { profile.commandIDs[.dualConnectionSet] != nil }
    var statusDetail: String {
        if isMockMode { return "Controls are simulated" }
        return profile.commandIDs.isEmpty ? "Nothing profile · commands not mapped" : "Bluetooth Classic RFCOMM"
    }

    var batteryMessage: String {
        guard connectionState == .connected else {
            return connectionState == .mock ? "Demo battery" : "Connect headphones to read battery"
        }
        return battery == nil ? "Waiting for battery report" : "Battery status received"
    }

    /// Name used to pick the product photo: the Bluetooth name macOS shows (for example "CMF Buds 2a")
    /// is tried first, because the model string a device reports is not always a readable name.
    var artworkModelName: String {
        [deviceName, deviceModel, displayModelName].compactMap { $0 }
            .first { ProductCatalog.assetName(for: $0) != nil } ?? displayModelName
    }

    var displayModelName: String {
        if ProductCatalog.assetName(for: deviceName) != nil, !isMockMode { return deviceName }
        if let deviceModel {
            let model = deviceModel.trimmingCharacters(in: .whitespacesAndNewlines)
            if !model.isEmpty, model.count < 48 { return model }
        }
        return deviceName
    }

    func toggleMockMode() {
        isMockMode.toggle()
    }

    func setNoiseMode(_ mode: ANCMode) {
        guard send(.ancSet, value: .anc(mode)) else { return }
        noiseMode = mode
    }

    func setANCIntensity(_ mode: ANCMode) {
        guard mode.isANC, send(.ancSet, value: .anc(mode)) else { return }
        ancIntensity = mode
        noiseMode = mode
    }

    func setEQ(_ preset: EQPreset) {
        if spatialAudioEnabled, preset != .balanced {
            guard send(.spatialSet, value: .spatial(false)) else { return }
            spatialAudioEnabled = false
        }
        guard send(.eqSet, value: .eq(preset)) else { return }
        eqPreset = preset
    }

    func setBassBoost(_ level: Int) {
        let bounded = min(5, max(0, level))
        if spatialAudioEnabled, bounded > 0 {
            guard send(.spatialSet, value: .spatial(false)) else { return }
            spatialAudioEnabled = false
        }
        guard send(.bassSet, value: .bass(bounded)) else { return }
        bassBoost = bounded
    }

    func setLowLatency(_ enabled: Bool) {
        guard send(.lowLatencySet, value: .lowLatency(enabled)) else { return }
        lowLatencyEnabled = enabled
    }

    func setSpatialAudio(_ enabled: Bool) {
        if enabled {
            if bassBoost > 0 {
                guard send(.bassSet, value: .bass(0)) else { return }
                bassBoost = 0
            }
            if eqPreset != .balanced {
                guard send(.eqSet, value: .eq(.balanced)) else { return }
                eqPreset = .balanced
            }
        }
        guard send(.spatialSet, value: .spatial(enabled)) else { return }
        spatialAudioEnabled = enabled
    }

    func setDualConnection(_ enabled: Bool) {
        guard send(.dualConnectionSet, value: .dualConnection(enabled)) else { return }
        dualConnectionEnabled = enabled
    }

    private static let inEarPreferenceKey = "cmf.inEarPreference"

    func setInEarDetection(_ enabled: Bool) {
        guard send(.inEarSet, value: .inEar(enabled)) else { return }
        inEarDetectionEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.inEarPreferenceKey)
    }

    func setCustomEQBand(_ index: Int, gain: Int) {
        guard customEQ.indices.contains(index) else { return }
        customEQ[index] = min(6, max(-6, gain))
        scheduleCustomEQSend()
    }

    /// Edits one band from the graph; moving a band turns the current preset into the custom curve.
    func editEQBand(_ index: Int, gain: Int) {
        if eqPreset != .custom { customEQ = eqPreset.indicativeBands }
        setCustomEQBand(index, gain: gain)
    }

    func resetCustomEQ() {
        customEQ = [0, 0, 0]
        scheduleCustomEQSend()
    }

    /// Slider drags produce many changes; send once the value settles.
    private func scheduleCustomEQSend() {
        customEQTask?.cancel()
        customEQTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, !Task.isCancelled, self.isConnected else { return }
            if self.eqPreset != .custom {
                guard self.send(.eqSet, value: .eq(.custom)) else { return }
                self.eqPreset = .custom
            }
            let bands = self.customEQ.map(Float.init)
            _ = self.send(.customEQSet, rawPayload: CustomEQCodec.setPayload(bass: bands[0], mid: bands[1], treble: bands[2]))
        }
    }

    func saveCurrentEQ(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        savedEQPresets.append(SavedEQPreset(name: trimmed, bands: customEQ))
    }

    func applyEQPreset(_ preset: SavedEQPreset) {
        guard preset.bands.count == 3 else { return }
        customEQ = preset.bands
        scheduleCustomEQSend()
    }

    func deleteEQPreset(_ preset: SavedEQPreset) {
        savedEQPresets.removeAll { $0.id == preset.id }
    }

    private func saveEQPresets() {
        if let data = try? JSONEncoder().encode(savedEQPresets) { UserDefaults.standard.set(data, forKey: "cmf.eqPresets") }
    }

    func setGesture(_ slot: GestureSlot, actionCode: UInt8) {
        guard send(.gestureSet, rawPayload: GestureCodec.setPayload(side: slot.side, gestureCode: slot.code, actionCode: actionCode)) else { return }
        gestures[slot] = actionCode
        // Re-read so the list shows what the device actually accepted.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            _ = self?.send(.gestureQuery)
        }
    }

    func refreshGestures() { _ = send(.gestureQuery) }

    /// Makes the buds beep so a lost one can be found. `side` nil rings both.
    func ring(_ side: EarSide?, on: Bool) {
        let sides = side.map { [$0] } ?? EarSide.allCases
        for earSide in sides {
            _ = send(.ringSet, rawPayload: [earSide.rawValue, on ? 0x01 : 0x00])
        }
        isRinging = on
        ringTask?.cancel()
        if on {
            ringTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(60))
                guard let self, !Task.isCancelled, self.isRinging else { return }
                self.ring(side, on: false)
            }
        }
    }

    // MARK: Devices

    func refreshKnownDevices() {
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        knownDevices = paired.filter(matches).map {
            KnownDevice(address: $0.addressString ?? "", name: $0.nameOrAddress ?? "Unknown", isConnected: $0.isConnected(), isPaired: true)
        }
    }

    func connect(toAddress address: String) {
        guard !isMockMode, let device = IOBluetoothDevice(addressString: address) else { return }
        if device != selectedDevice || connectionState == .disconnected {
            reconnectTask?.cancel()
            channelProbeTask?.cancel()
            channel?.close()
            channel = nil
            releasePendingWriteBuffers()
            selectedDevice = nil
            connectionState = .disconnected
            consider(device)
        }
    }

    func startScan() {
        guard !isMockMode, !isScanning else { return }
        discoveredDevices = []
        refreshKnownDevices()
        let search = IOBluetoothDeviceInquiry(delegate: bridge)
        search?.inquiryLength = 12
        search?.updateNewDeviceNames = true
        inquiry = search
        isScanning = search?.start() == kIOReturnSuccess
    }

    func stopScan() {
        inquiry?.stop()
        isScanning = false
    }

    func pair(address: String) {
        guard let device = IOBluetoothDevice(addressString: address) else { return }
        pairing = IOBluetoothDevicePair(device: device)
        pairing?.delegate = bridge
        if pairing?.start() != kIOReturnSuccess { lastError = "Could not start pairing" }
    }

    private func inquiryFound(_ device: IOBluetoothDevice) {
        guard matches(device), let address = device.addressString,
              !discoveredDevices.contains(where: { $0.address == address }) else { return }
        discoveredDevices.append(KnownDevice(address: address, name: device.nameOrAddress ?? "Nothing device",
                                             isConnected: device.isConnected(), isPaired: device.isPaired()))
    }

    private func pairingFinished(_ error: IOReturn) {
        pairing = nil
        refreshKnownDevices()
        if error != kIOReturnSuccess { lastError = "Pairing failed (\(error))"; return }
        discoveredDevices.removeAll()
    }

    func sendInitialStateSync() {
        waitingForDeviceInfo = false
        initialSyncTask?.cancel()
        initialSyncTask = nil
        _ = send(.batteryQuery)
        _ = send(.ancQuery)
        _ = send(.eqQuery)
        _ = send(.bassQuery)
        _ = send(.lowLatencyQuery)
        _ = send(.spatialQuery)
        _ = send(.dualConnectionQuery)
        _ = send(.inEarQuery)
        // Re-apply the saved choice so pausing on removal follows the user across every device and reconnect.
        if let preference = UserDefaults.standard.object(forKey: Self.inEarPreferenceKey) as? Bool {
            _ = send(.inEarSet, value: .inEar(preference))
            inEarDetectionEnabled = preference
        }
        _ = send(.firmwareQuery)
        _ = send(.modelQuery)
        _ = send(.customEQQuery)
        _ = send(.gestureQuery)
        startBatteryPolling()
    }

    func refreshBattery() {
        guard isConnected else { scanPairedDevices(); return }
        guard !isMockMode else { return }
        _ = send(.batteryQuery)
        startBatteryPolling()
    }

    func scanPairedDevices() {
        guard !isMockMode else { return }
        connectionState = .discovering
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        if let connected = paired.first(where: { matches($0) && $0.isConnected() }) {
            consider(connected)
            return
        }
        if let candidate = paired.first(where: matches) {
            selectedDevice = candidate
            deviceName = candidate.nameOrAddress ?? profile.displayName
            connectionState = .disconnected
        } else {
            deviceName = "No Nothing / CMF headphones"
            connectionState = .disconnected
        }
    }

    func clearPacketLog() { packetLog.removeAll() }

    private func updateMockMode() {
        reconnectTask?.cancel()
        reconnectTask = nil
        if isMockMode {
            disconnectNotification?.unregister()
            disconnectNotification = nil
            channel?.close()
            releasePendingWriteBuffers()
            selectedDevice = nil
            channel = nil
            deviceName = "CMF Headphones Pro · Demo"
            connectionState = .mock
            battery = BatteryStatus(
                headset: BatteryComponent(percentage: 82, isCharging: false),
                left: nil,
                right: nil,
                caseBattery: nil
            )
            batteryLastUpdated = Date()
            firmwareVersion = "1.0.0-demo"
            deviceModel = "CMF Headphones Pro"
            serialNumber = "DEMO0000000000"
            deviceAddress = "00:00:00:00:00:00"
            gestures = [
                GestureSlot(side: .left, gesture: .doubleTap): GestureAction.playPause.rawValue,
                GestureSlot(side: .left, gesture: .tripleTap): GestureAction.skipForward.rawValue,
                GestureSlot(side: .left, gesture: .tapAndHold): GestureAction.noiseAncOff.rawValue,
                GestureSlot(side: .right, gesture: .doubleTap): GestureAction.skipForward.rawValue,
                GestureSlot(side: .right, gesture: .tripleTap): GestureAction.skipBack.rawValue,
                GestureSlot(side: .right, gesture: .tapAndHold): GestureAction.noiseControl.rawValue
            ]
        } else {
            battery = nil
            batteryLastUpdated = nil
            firmwareVersion = nil
            deviceModel = nil
            scanPairedDevices()
        }
    }

    private func matches(_ device: IOBluetoothDevice) -> Bool {
        let name = (device.nameOrAddress ?? "").lowercased()
        return profile.nameMarkers.contains(where: name.contains)
    }

    private func consider(_ device: IOBluetoothDevice) {
        guard !isMockMode, !isSleeping, matches(device) else { return }
        // Opening our own channel raises more system connect events; one attempt at a time avoids a reconnect loop.
        if device == selectedDevice, connectionState == .connecting || connectionState == .connected { return }
        if selectedDevice != device {
            battery = nil
            batteryLastUpdated = nil
            firmwareVersion = nil
            deviceModel = nil
            serialNumber = nil
            gestures = [:]
        }
        selectedDevice = device
        deviceAddress = device.addressString
        deviceName = device.nameOrAddress ?? profile.displayName
        connectionState = .connecting
        channelOpenRetries = 0
        disconnectNotification?.unregister()
        disconnectNotification = device.register(forDisconnectNotification: bridge,
                                                  selector: #selector(CMFBluetoothBridge.deviceDisconnected(_:device:)))
        beginConnection(device)
    }

    /// Registers this process as a client of the baseband link first; without it the RFCOMM open can hang forever.
    private func beginConnection(_ device: IOBluetoothDevice) {
        connectionAttempt += 1
        let attempt = connectionAttempt
        let box = UncheckedBox(device)
        Task.detached { [weak self] in
            var status = box.value.openConnection()
            var tries = 0
            while status != kIOReturnSuccess, tries < 2 {
                try? await Task.sleep(for: .seconds(1))
                status = box.value.openConnection()
                tries += 1
            }
            let result = status
            await MainActor.run { [weak self] in
                guard let self, self.connectionAttempt == attempt, !self.isMockMode, device == self.selectedDevice else { return }
                guard result == kIOReturnSuccess else {
                    self.lastError = "Could not connect to the device (\(result))"
                    self.connectionState = .disconnected
                    self.reconnectSelectedDevice()
                    return
                }
                if device.performSDPQuery(self.bridge) != kIOReturnSuccess {
                    self.channelCandidates = [self.rememberedChannel(for: device), self.fallbackChannelID(for: device)]
                        .compactMap { $0 }
                    self.openNextCandidate(device)
                }
            }
        }
    }

    private func systemWillSleep() {
        isSleeping = true
        reconnectTask?.cancel()
        guard !isMockMode, selectedDevice != nil else { return }
        // The channel dies silently during sleep; close it cleanly and reattach on wake.
        channelProbeTask?.cancel()
        channel?.close()
        channel = nil
        releasePendingWriteBuffers()
        connectionState = .disconnected
    }

    private func systemDidWake() {
        isSleeping = false
        guard !isMockMode, selectedDevice != nil else { return }
        reconnectFailures = 0
        reconnectSelectedDevice(after: .seconds(3))
    }

    private func sdpCompleted(_ device: IOBluetoothDevice, status: IOReturn) {
        guard device == selectedDevice, !isMockMode else { return }
        guard status == kIOReturnSuccess else {
            channelCandidates = [rememberedChannel(for: device), fallbackChannelID(for: device)]
                .compactMap { $0 }
            openNextCandidate(device)
            return
        }
        var candidates: [BluetoothRFCOMMChannelID] = []
        func add(_ id: BluetoothRFCOMMChannelID) { if id > 0, !candidates.contains(id) { candidates.append(id) } }
        func channel(of record: IOBluetoothSDPServiceRecord) -> BluetoothRFCOMMChannelID? {
            var id: BluetoothRFCOMMChannelID = 0
            return record.getRFCOMMChannelID(&id) == kIOReturnSuccess && id > 0 ? id : nil
        }

        if let remembered = rememberedChannel(for: device) { add(remembered) }
        if let serviceUUID = profile.serviceUUID, let uuid = sdpUUID(serviceUUID),
           let record = device.getServiceRecord(for: uuid), let id = channel(of: record) {
            add(id)
        }
        // Not every model publishes the Nothing UUID; try the other serial records, skipping audio profiles.
        let audioNames = ["hands", "headset", "hfp", "hsp", "audio"]
        for record in (device.services as? [IOBluetoothSDPServiceRecord]) ?? [] {
            let name = (record.getServiceName() ?? "").lowercased()
            guard !audioNames.contains(where: name.contains), let id = channel(of: record) else { continue }
            add(id)
        }
        add(fallbackChannelID(for: device))
        channelCandidates = candidates
        openNextCandidate(device)
    }

    private func openNextCandidate(_ device: IOBluetoothDevice) {
        guard device == selectedDevice, !isMockMode else { return }
        guard !channelCandidates.isEmpty else {
            lastError = "No Nothing control channel found on this device"
            connectionState = .disconnected
            reconnectSelectedDevice()
            return
        }
        openChannel(device, channelID: channelCandidates.removeFirst())
    }

    private func rememberedChannel(for device: IOBluetoothDevice) -> BluetoothRFCOMMChannelID? {
        let value = UserDefaults.standard.integer(forKey: "cmf.channel.\(device.addressString ?? "")")
        return value > 0 ? BluetoothRFCOMMChannelID(value) : nil
    }

    private func fallbackChannelID(for device: IOBluetoothDevice) -> BluetoothRFCOMMChannelID {
        let name = (device.nameOrAddress ?? "").lowercased()
        if name.contains("cmf headphone pro") { return 28 }
        if name.contains("cmf buds 2") { return 16 }
        return 15
    }

    private func sdpUUID(_ string: String) -> IOBluetoothSDPUUID? {
        guard let uuid = UUID(uuidString: string) else { return nil }
        var value = uuid.uuid
        return withUnsafeBytes(of: &value) { IOBluetoothSDPUUID(data: Data($0)) }
    }

    private func openChannel(_ device: IOBluetoothDevice, channelID: BluetoothRFCOMMChannelID) {
        guard device == selectedDevice else { return }
        connectionState = .connecting
        var newChannel: IOBluetoothRFCOMMChannel?
        let result = device.openRFCOMMChannelAsync(&newChannel, withChannelID: channelID, delegate: bridge)
        if result == kIOReturnSuccess {
            channel = newChannel
            channelProbeTask?.cancel()
            channelProbeTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard let self, !Task.isCancelled, self.connectionState == .connecting,
                      let pending = self.channel, pending === newChannel else { return }
                self.channel = nil
                pending.close()
                self.lastError = "Channel \(channelID) did not open"
                if self.channelOpenRetries < 2 {
                    self.channelOpenRetries += 1
                    self.openChannel(device, channelID: channelID)
                } else if self.channelCandidates.isEmpty {
                    self.connectionState = .disconnected
                    self.reconnectSelectedDevice()
                } else {
                    self.openNextCandidate(device)
                }
            }
        }
        else {
            lastError = "Could not open RFCOMM channel \(channelID) (\(result))"
            if channelCandidates.isEmpty {
                connectionState = .disconnected
                reconnectSelectedDevice()
            } else {
                openNextCandidate(device)
            }
        }
    }

    private func channelOpened(_ openedChannel: IOBluetoothRFCOMMChannel, status: IOReturn) {
        guard status == kIOReturnSuccess else {
            lastError = "RFCOMM open failed (\(status))"
            channel = nil
            if let device = selectedDevice, !channelCandidates.isEmpty {
                openNextCandidate(device)
            } else {
                connectionState = .disconnected
                reconnectSelectedDevice()
            }
            return
        }
        channel = openedChannel
        connectionState = .connected
        lastError = nil
        channelOpenRetries = 0
        reconnectFailures = 0
        receivedNothingFrame = false
        verifyChannelResponds(openedChannel)
        waitingForDeviceInfo = true
        _ = send(.deviceInfoQuery)
        initialSyncTask?.cancel()
        initialSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard let self, self.waitingForDeviceInfo, self.connectionState == .connected else { return }
            self.sendInitialStateSync()
        }
    }

    /// Some channels open fine but are not the Nothing control service; move on if nothing valid arrives.
    private func verifyChannelResponds(_ openedChannel: IOBluetoothRFCOMMChannel) {
        channelProbeTask?.cancel()
        channelProbeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled, self.channel === openedChannel else { return }
            if self.receivedNothingFrame { return }
            guard let device = self.selectedDevice, !self.channelCandidates.isEmpty else {
                self.lastError = "Device opened a channel but did not answer Nothing commands"
                return
            }
            self.channel = nil
            openedChannel.close()
            self.releasePendingWriteBuffers()
            self.openNextCandidate(device)
        }
    }

    private func channelClosed(_ closedChannel: IOBluetoothRFCOMMChannel?) {
        // A channel we abandoned while probing for the right service must not tear down its replacement.
        guard closedChannel == nil || closedChannel === channel else { return }
        channel = nil
        releasePendingWriteBuffers()
        batteryQueryTask?.cancel()
        batteryQueryTask = nil
        guard !isMockMode else { return }
        connectionState = .disconnected
        reconnectSelectedDevice()
    }

    private func deviceDisconnected(_ device: IOBluetoothDevice) {
        guard device == selectedDevice else { return }
        channel?.close()
        channel = nil
        connectionState = .disconnected
        batteryQueryTask?.cancel()
        batteryQueryTask = nil
        reconnectSelectedDevice()
    }

    private func reconnectSelectedDevice(after delay: Duration? = nil) {
        guard let selectedDevice, !isMockMode, !isSleeping else { return }
        reconnectTask?.cancel()
        // Back off so a device that keeps refusing is not hammered, which shows as connect/disconnect flicker.
        let wait = delay ?? .seconds(min(30, 3 << min(reconnectFailures, 3)))
        reconnectFailures += 1
        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: wait)
            guard let self, !Task.isCancelled, !self.isMockMode, !self.isSleeping, self.selectedDevice == selectedDevice,
                  self.connectionState != .connected, self.connectionState != .connecting else { return }
            self.consider(selectedDevice)
        }
    }

    @discardableResult
    private func send(_ kind: CMFCommandKind, value: CMFControlValue? = nil, rawPayload: [UInt8]? = nil) -> Bool {
        if isMockMode {
            let packetSequence = nextSequence()
            let packet = rawPayload.flatMap { profile.packet(for: kind, rawPayload: $0, sequence: packetSequence) }
                ?? profile.packet(for: kind, value: value, sequence: packetSequence)
                ?? NothingPacket(commandID: 0xFFFF,
                                 sequence: packetSequence,
                                 payload: value.map { Array(String(describing: $0).utf8) } ?? [])
            appendLog(direction: "TX · DEMO", bytes: packet.encoded())
            return true
        }
        guard connectionState == .connected else {
            lastError = "Connect a Nothing / CMF headset or enable demo mode"
            return false
        }
        let packetSequence = nextSequence()
        guard let packet = rawPayload.flatMap({ profile.packet(for: kind, rawPayload: $0, sequence: packetSequence) })
            ?? profile.packet(for: kind, value: value, sequence: packetSequence) else {
            lastError = "This command is not mapped in the Nothing profile yet"
            return false
        }
        guard channel != nil else {
            lastError = "RFCOMM channel is unavailable"
            return false
        }
        let bytes = packet.encoded()
        guard bytes.count <= Int(UInt16.max) else { return false }
        appendLog(direction: "TX", bytes: bytes)
        outboundFrames.append(bytes)
        writeNextFrame()
        return true
    }

    /// Synchronous writes, as the working reference apps use; the async path never produced a reply from the buds.
    private func writeNextFrame() {
        guard let channel else { return }
        while !outboundFrames.isEmpty {
            var bytes = outboundFrames.removeFirst()
            let result = bytes.withUnsafeMutableBytes { raw in
                channel.writeSync(raw.baseAddress, length: UInt16(raw.count))
            }
            if result != kIOReturnSuccess { lastError = "RFCOMM write failed (\(result))" }
        }
    }

    private func writeCompleted(_ refcon: UnsafeMutableRawPointer?, status: IOReturn) {
        guard let refcon else { return }
        let key = UInt(bitPattern: refcon)
        pendingWriteBuffers.removeValue(forKey: key)?.deallocate()
        writeInFlight = false
        if status != kIOReturnSuccess { lastError = "RFCOMM write failed (\(status))" }
        writeNextFrame()
    }

    private func releasePendingWriteBuffers() {
        initialSyncTask?.cancel()
        initialSyncTask = nil
        waitingForDeviceInfo = false
        batteryQueryTask?.cancel()
        batteryQueryTask = nil
        for buffer in pendingWriteBuffers.values { buffer.deallocate() }
        pendingWriteBuffers.removeAll()
        outboundFrames.removeAll()
        writeInFlight = false
    }

    private func receive(_ bytes: [UInt8]) {
        appendLog(direction: "RX", bytes: bytes)
        for packet in parser.append(bytes) {
            if !receivedNothingFrame {
                receivedNothingFrame = true
                if let device = selectedDevice, let id = channel?.getID() {
                    UserDefaults.standard.set(Int(id), forKey: "cmf.channel.\(device.addressString ?? "")")
                }
            }
            if packet.commandID == 0xE001 {
                applyBatteryReport(packet.payload)
                continue
            }
            if packet.commandID == 0xE003 {
                applyANCReport(packet.payload)
                continue
            }
            guard let command = profile.commandIDs.first(where: { ($0.value & 0x7FFF) == packet.commandID })?.key else { continue }
            switch command {
            case .deviceInfoQuery:
                let info = DeviceInfoReport.parse(packet.payload)
                if let serial = info.serial { serialNumber = serial }
                if waitingForDeviceInfo { sendInitialStateSync() }
            case .customEQQuery:
                if let bands = CustomEQCodec.parse(packet.payload) {
                    let rounded = [bands.bass, bands.mid, bands.treble].map { Int(max(-6, min(6, $0.rounded()))) }
                    if customEQTask == nil || customEQTask?.isCancelled == true { customEQ = rounded }
                }
            case .gestureQuery:
                gestures.merge(GestureCodec.parse(packet.payload)) { _, new in new }
            case .batteryQuery:
                applyBatteryReport(packet.payload)
            case .ancQuery:
                applyANCReport(packet.payload)
            case .eqQuery:
                if let value = packet.payload.first {
                    switch value {
                    case 0x00: eqPreset = .balanced
                    case 0x01: eqPreset = .voice
                    case 0x02: eqPreset = .moreTreble
                    case 0x03: eqPreset = .moreBass
                    case 0x05: eqPreset = .custom
                    default: break
                    }
                }
            case .bassQuery:
                if packet.payload.count >= 2 {
                    bassBoost = packet.payload[0] == 0 ? 0 : min(5, Int(packet.payload[1]))
                }
            case .lowLatencyQuery:
                if let value = packet.payload.first { lowLatencyEnabled = value == 0x01 }
            case .spatialQuery:
                if let value = packet.payload.first { spatialAudioEnabled = value != 0x00 }
            case .dualConnectionQuery:
                if let value = packet.payload.first { dualConnectionEnabled = value != 0x00 }
            case .inEarQuery:
                if packet.payload.count == 3, packet.payload[0] == 0x01, packet.payload[1] == 0x01 {
                    if UserDefaults.standard.object(forKey: Self.inEarPreferenceKey) == nil {
                        inEarDetectionEnabled = packet.payload[2] != 0x00
                    }
                }
            case .firmwareQuery, .modelQuery:
                let value = String(decoding: packet.payload, as: UTF8.self).trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines))
                if command == .firmwareQuery { firmwareVersion = value }
                else { deviceModel = value }
            default: break
            }
        }
    }

    private func applyANCReport(_ payload: [UInt8]) {
        guard payload.count >= 3 else { return }
        for offset in stride(from: 0, through: payload.count - 3, by: 3) where payload[offset] == 0x01 {
            switch payload[offset + 1] {
            case 0x01: ancIntensity = .high; noiseMode = .high
            case 0x02: ancIntensity = .mid; noiseMode = .mid
            case 0x03: ancIntensity = .low; noiseMode = .low
            case 0x04: ancIntensity = .adaptive; noiseMode = .adaptive
            case 0x05: noiseMode = .off
            case 0x07: noiseMode = .transparency
            default: break
            }
        }
    }

    private func applyBatteryReport(_ payload: [UInt8]) {
        guard let report = BatteryStatus.parse(payload) else { return }
        battery = BatteryStatus(
            headset: report.headset ?? battery?.headset,
            left: report.left ?? battery?.left,
            right: report.right ?? battery?.right,
            caseBattery: report.caseBattery ?? battery?.caseBattery
        )
        batteryLastUpdated = Date()
    }

    private func startBatteryPolling() {
        batteryQueryTask?.cancel()
        batteryQueryTask = Task { @MainActor [weak self] in
            let retryDelays: [Duration] = [.seconds(2), .seconds(4), .seconds(8), .seconds(15)]
            var retryIndex = 0
            while !Task.isCancelled {
                guard let self, self.connectionState == .connected, !self.isMockMode else { return }
                let delay = retryIndex < retryDelays.count ? retryDelays[retryIndex] : .seconds(60)
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, self.connectionState == .connected else { return }
                _ = self.send(.batteryQuery)
                if retryIndex < retryDelays.count { retryIndex += 1 }
            }
        }
    }

    private func appendLog(direction: String, bytes: [UInt8]) {
        packetLog.append(PacketLogEntry(direction: direction, bytes: bytes))
        if packetLog.count > 200 { packetLog.removeFirst(packetLog.count - 200) }
    }

    private func nextSequence() -> UInt8 {
        defer { sequence &+= 1 }
        return sequence
    }
}

private final class UncheckedBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

private final class CMFBluetoothBridge: NSObject, IOBluetoothRFCOMMChannelDelegate, IOBluetoothDeviceInquiryDelegate, IOBluetoothDevicePairDelegate {
    var onConnected: ((IOBluetoothDevice) -> Void)?
    var onDisconnected: ((IOBluetoothDevice) -> Void)?
    var onSDPComplete: ((IOBluetoothDevice, IOReturn) -> Void)?
    var onChannelOpen: ((IOBluetoothRFCOMMChannel, IOReturn) -> Void)?
    var onChannelClose: ((IOBluetoothRFCOMMChannel?) -> Void)?
    var onData: (([UInt8]) -> Void)?
    var onWriteComplete: ((UnsafeMutableRawPointer?, IOReturn) -> Void)?
    var onInquiryFound: ((IOBluetoothDevice) -> Void)?
    var onInquiryComplete: (() -> Void)?
    var onPairingFinished: ((IOReturn) -> Void)?

    @objc func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        if let device { onInquiryFound?(device) }
    }

    @objc func deviceInquiryDeviceNameUpdated(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!, devicesRemaining: UInt32) {
        if let device { onInquiryFound?(device) }
    }

    @objc func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
        onInquiryComplete?()
    }

    @objc func devicePairingFinished(_ sender: Any!, error: IOReturn) {
        onPairingFinished?(error)
    }

    @objc func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        onConnected?(device)
    }

    @objc func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        onDisconnected?(device)
    }

    @objc func sdpQueryComplete(_ device: IOBluetoothDevice, status: IOReturn) {
        onSDPComplete?(device, status)
    }

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        guard let dataPointer, dataLength > 0 else { return }
        onData?(Array(UnsafeBufferPointer(start: dataPointer.assumingMemoryBound(to: UInt8.self), count: dataLength)))
    }

    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        onChannelOpen?(rfcommChannel, error)
    }

    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        onChannelClose?(rfcommChannel)
    }

    func rfcommChannelWriteComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, refcon: UnsafeMutableRawPointer!, status error: IOReturn) {
        onWriteComplete?(refcon, error)
    }
}
