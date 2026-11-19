import Foundation

enum ANCMode: String, CaseIterable, Identifiable, Sendable {
    case off = "Off"
    case transparency = "Transparency"
    case low = "ANC Low"
    case mid = "ANC Mid"
    case high = "ANC High"
    case adaptive = "Adaptive"
    var id: String { rawValue }
    var isANC: Bool { self == .low || self == .mid || self == .high || self == .adaptive }
}

enum EQPreset: String, CaseIterable, Identifiable, Sendable {
    case balanced = "Balanced"
    case voice = "Voice"
    case moreBass = "More Bass"
    case moreTreble = "More Treble"
    case custom = "Custom"
    var id: String { rawValue }
}

enum CMFCommandKind: String, CaseIterable, Hashable, Sendable {
    case deviceInfoQuery, batteryQuery, ancQuery, ancSet, eqQuery, eqSet, bassQuery, bassSet
    case lowLatencyQuery, lowLatencySet, spatialQuery, spatialSet
    case dualConnectionQuery, dualConnectionSet, firmwareQuery, modelQuery
    case inEarQuery, inEarSet
    case customEQQuery, customEQSet, gestureQuery, gestureSet, ringSet
}

enum CMFControlValue: Hashable, Sendable {
    case anc(ANCMode)
    case eq(EQPreset)
    case bass(Int)
    case lowLatency(Bool)
    case spatial(Bool)
    case dualConnection(Bool)
    case inEar(Bool)
}

struct CMFDeviceProfile: Sendable {
    let displayName: String
    let nameMarkers: [String]
    let serviceUUID: String?
    let commandIDs: [CMFCommandKind: UInt16]
    let encodedValues: [CMFControlValue: [UInt8]]

    static let nothingEarFamily = CMFDeviceProfile(
        displayName: "Nothing / CMF headphones",
        nameMarkers: ["nothing", "cmf"],
        serviceUUID: "aeac4a03-dff5-498f-843a-34487cf133eb",
        commandIDs: [
            .deviceInfoQuery: 0xC006,
            .batteryQuery: 0xC007,
            .ancQuery: 0xC01E,
            .ancSet: 0xF00F,
            .eqQuery: 0xC01F,
            .eqSet: 0xF010,
            .bassQuery: 0xC04E,
            .bassSet: 0xF051,
            .lowLatencyQuery: 0xC041,
            .lowLatencySet: 0xF040,
            .spatialQuery: 0xC04F,
            .spatialSet: 0xF052,
            .dualConnectionQuery: 0xC027,
            .firmwareQuery: 0xC042,
            .modelQuery: 0xC01C,
            .inEarQuery: 0xC00E,
            .inEarSet: 0xF004,
            .customEQQuery: 0xC024,
            .customEQSet: 0xF041,
            .gestureQuery: 0xC018,
            .gestureSet: 0xF003,
            .ringSet: 0xF002
        ],
        encodedValues: [
            .anc(.high): [0x01, 0x01, 0x00],
            .anc(.mid): [0x01, 0x02, 0x00],
            .anc(.low): [0x01, 0x03, 0x00],
            .anc(.adaptive): [0x01, 0x04, 0x00],
            .anc(.off): [0x01, 0x05, 0x00],
            .anc(.transparency): [0x01, 0x07, 0x00],
            .eq(.balanced): [0x00],
            .eq(.voice): [0x01],
            .eq(.moreTreble): [0x02],
            .eq(.moreBass): [0x03],
            .eq(.custom): [0x05],
            .lowLatency(true): [0x01],
            .lowLatency(false): [0x02],
            .spatial(true): [0x01],
            .spatial(false): [0x00],
            .inEar(true): [0x01, 0x01, 0x01],
            .inEar(false): [0x01, 0x01, 0x00]
        ]
    )

    /// Builds a packet whose payload is already encoded (custom EQ, gestures, ring).
    func packet(for command: CMFCommandKind, rawPayload: [UInt8], sequence: UInt8) -> NothingPacket? {
        guard let commandID = commandIDs[command] else { return nil }
        return NothingPacket(commandID: commandID, sequence: sequence, payload: rawPayload)
    }

    func packet(for command: CMFCommandKind, value: CMFControlValue? = nil, sequence: UInt8) -> NothingPacket? {
        guard let commandID = commandIDs[command] else { return nil }
        let payload: [UInt8]
        if let value {
            if case let .bass(level) = value {
                guard (0...5).contains(level) else { return nil }
                payload = level == 0 ? [0x00, 0x00] : [0x01, UInt8(level)]
            } else {
                guard let encoded = encodedValues[value] else { return nil }
                payload = encoded
            }
        } else {
            payload = []
        }
        return NothingPacket(commandID: commandID, sequence: sequence, payload: payload)
    }
}

struct BatteryComponent: Equatable, Sendable {
    let percentage: Int
    let isCharging: Bool
}

struct BatteryStatus: Equatable, Sendable {
    let headset: BatteryComponent?
    let left: BatteryComponent?
    let right: BatteryComponent?
    let caseBattery: BatteryComponent?

    static func parse(_ payload: [UInt8]) -> BatteryStatus? {
        guard let count = payload.first, payload.count >= 1 + Int(count) * 2 else { return nil }
        var headset: BatteryComponent?
        var left: BatteryComponent?
        var right: BatteryComponent?
        var caseBattery: BatteryComponent?
        var unclassified: [BatteryComponent] = []
        for index in 0..<Int(count) {
            let offset = 1 + index * 2
            let percentage = Int(payload[offset + 1] & 0x7F)
            guard (0...100).contains(percentage) else { continue }
            let component = BatteryComponent(percentage: Int(payload[offset + 1] & 0x7F),
                                            isCharging: payload[offset + 1] & 0x80 != 0)
            switch payload[offset] {
            case 0x02: left = component
            case 0x03: right = component
            case 0x04: caseBattery = component
            case 0x06: headset = component
            default: unclassified.append(component)
            }
        }
        // Over-ear products may report one aggregate battery with a model-specific ID.
        if count == 1, headset == nil, left == nil, right == nil, caseBattery == nil,
           let onlyComponent = unclassified.first {
            headset = onlyComponent
        }
        if headset == nil, left == nil, right == nil, caseBattery == nil, let first = unclassified.first {
            headset = first
        }
        let result = BatteryStatus(headset: headset, left: left, right: right, caseBattery: caseBattery)
        return [headset, left, right, caseBattery].contains(where: { $0 != nil }) ? result : nil
    }
}

struct FirmwareIdentity: Equatable, Sendable {
    let firmwareVersion: String?
    let deviceModel: String?

    static func parse(_ payload: [UInt8], firmwareRange: Range<Int>?, modelRange: Range<Int>?) -> FirmwareIdentity {
        func string(_ range: Range<Int>?) -> String? {
            guard let range, range.lowerBound >= 0, range.upperBound <= payload.count else { return nil }
            let text = String(decoding: payload[range], as: UTF8.self)
                .trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines))
            return text.isEmpty ? nil : text
        }
        return FirmwareIdentity(firmwareVersion: string(firmwareRange), deviceModel: string(modelRange))
    }
}


enum EarSide: UInt8, CaseIterable, Identifiable, Sendable {
    case left = 2
    case right = 3
    var id: UInt8 { rawValue }
    var title: String { self == .left ? "Left" : "Right" }
}

enum GestureKind: UInt8, CaseIterable, Identifiable, Sendable {
    case doubleTap = 2
    case tripleTap = 3
    case tapAndHold = 7
    case doubleTapAndHold = 9
    var id: UInt8 { rawValue }

    var title: String {
        switch self {
        case .doubleTap: "Double tap"
        case .tripleTap: "Triple tap"
        case .tapAndHold: "Press and hold"
        case .doubleTapAndHold: "Double press and hold"
        }
    }

    /// Action codes the device accepts for this gesture.
    var allowedActions: [GestureAction] {
        switch self {
        case .doubleTap: [.playPause, .skipBack, .skipForward, .voiceAssistant, .none]
        case .tripleTap: [.skipBack, .skipForward, .voiceAssistant, .none]
        case .tapAndHold, .doubleTapAndHold:
            [.noiseControl, .noiseAncOff, .noiseTransOff, .noiseAncTrans, .voiceAssistant, .volumeUp, .volumeDown, .none]
        }
    }
}

enum GestureAction: UInt8, Identifiable, Sendable, CaseIterable {
    case none = 1
    case playPause = 2
    case skipBack = 8
    case skipForward = 9
    case noiseControl = 10
    case voiceAssistant = 11
    case volumeUp = 18
    case volumeDown = 19
    case noiseAncOff = 20
    case noiseTransOff = 21
    case noiseAncTrans = 22
    var id: UInt8 { rawValue }

    var title: String {
        switch self {
        case .none: "No extra action"
        case .playPause: "Play / pause"
        case .skipBack: "Previous track"
        case .skipForward: "Next track"
        case .noiseControl, .noiseAncOff, .noiseTransOff, .noiseAncTrans: "Noise control"
        case .voiceAssistant: "Voice assistant"
        case .volumeUp: "Volume up"
        case .volumeDown: "Volume down"
        }
    }

    var isNoiseControl: Bool {
        switch self {
        case .noiseControl, .noiseAncOff, .noiseTransOff, .noiseAncTrans: true
        default: false
        }
    }

    /// Which modes the press cycles through; only meaningful for noise-control actions.
    var cycle: (anc: Bool, transparency: Bool, off: Bool) {
        switch self {
        case .noiseAncOff: (true, false, true)
        case .noiseTransOff: (false, true, true)
        case .noiseAncTrans: (true, true, false)
        default: (true, true, true)
        }
    }

    static func noise(anc: Bool, transparency: Bool, off: Bool) -> GestureAction {
        switch (anc, transparency, off) {
        case (true, false, true): .noiseAncOff
        case (false, true, true): .noiseTransOff
        case (true, true, false): .noiseAncTrans
        default: .noiseControl
        }
    }
}

/// A gesture on one earbud. The code is kept raw so gestures this app does not know still show up.
struct GestureSlot: Hashable, Sendable, Comparable {
    let side: EarSide
    let code: UInt8

    init(side: EarSide, gesture: GestureKind) { self.init(side: side, code: gesture.rawValue) }
    init(side: EarSide, code: UInt8) { self.side = side; self.code = code }

    var kind: GestureKind? { GestureKind(rawValue: code) }
    var title: String { kind?.title ?? "Gesture \(code)" }
    var allowedActions: [GestureAction] { kind?.allowedActions ?? GestureAction.allCases }

    static func < (lhs: GestureSlot, rhs: GestureSlot) -> Bool { lhs.code < rhs.code }
}

enum GestureCodec {
    static func setPayload(side: EarSide, gestureCode: UInt8, actionCode: UInt8) -> [UInt8] {
        [0x01, side.rawValue, 0x01, gestureCode, actionCode]
    }

    /// Reply layout: count, then per gesture `[side, ?, gesture, action]`. Codes are returned raw.
    static func parse(_ payload: [UInt8]) -> [GestureSlot: UInt8] {
        guard let count = payload.first else { return [:] }
        var result: [GestureSlot: UInt8] = [:]
        for index in 0..<Int(count) {
            let base = 1 + index * 4
            guard base + 3 < payload.count, let side = EarSide(rawValue: payload[base]) else { continue }
            result[GestureSlot(side: side, code: payload[base + 2])] = payload[base + 3]
        }
        return result
    }
}

enum CustomEQCodec {
    private static let bassParams: [UInt8] = [0x00, 0x00, 0x75, 0x44, 0xc3, 0xf5, 0x28, 0x3f]
    private static let midParams: [UInt8] = [0x00, 0xc0, 0x5a, 0x45, 0x00, 0x00, 0x80, 0x3f]
    private static let trebleParams: [UInt8] = [0x00, 0x00, 0x0c, 0x43, 0xcd, 0xcc, 0x4c, 0x3f]

    /// Little-endian float32; a positive overall gain is written as negative zero, as the official app does.
    private static func encode(_ value: Float, isTotal: Bool = false) -> [UInt8] {
        if isTotal && value >= 0 { return [0x00, 0x00, 0x00, 0x80] }
        var bytes = withUnsafeBytes(of: value.bitPattern.littleEndian) { Array($0) }
        if value != 0, bytes[3] == 0, bytes[2] == 0, bytes[1] == 0 { bytes[0] |= 0x80 }
        return bytes
    }

    private static func decode(_ bytes: ArraySlice<UInt8>) -> Float {
        guard bytes.count == 4 else { return 0 }
        let raw = bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * UInt32($1.offset)) }
        return Float(bitPattern: raw)
    }

    static func setPayload(bass: Float, mid: Float, treble: Float) -> [UInt8] {
        var payload: [UInt8] = [0x03]
        payload += encode(-max(bass, mid, treble), isTotal: true)
        payload += [0x01] + encode(bass) + [0x00] + bassParams
        payload += [0x02] + encode(mid) + midParams
        payload += [0x00] + encode(treble) + trebleParams
        payload += [0x00]
        return payload
    }

    /// Returns (bass, mid, treble) in dB from a query reply payload.
    static func parse(_ payload: [UInt8]) -> (bass: Float, mid: Float, treble: Float)? {
        guard payload.count >= 36 else { return nil }
        return (decode(payload[19..<23]), decode(payload[32..<36]), decode(payload[6..<10]))
    }
}

/// Reply to the device-info query: newline separated `device,type,value` rows (type 2 firmware, 4 serial).
struct DeviceInfoReport: Equatable, Sendable {
    let serial: String?
    let firmware: String?

    static func parse(_ payload: [UInt8]) -> DeviceInfoReport {
        var serial: String?
        var firmware: String?
        let text = String(decoding: payload, as: UTF8.self)
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: ",", maxSplits: 2).map(String.init)
            guard parts.count == 3 else { continue }
            let value = parts[2].trimmingCharacters(in: .controlCharacters.union(.whitespaces))
            guard !value.isEmpty else { continue }
            if parts[1] == "4", serial == nil { serial = value }
            if parts[1] == "2", firmware == nil { firmware = value }
        }
        return DeviceInfoReport(serial: serial, firmware: firmware)
    }
}
