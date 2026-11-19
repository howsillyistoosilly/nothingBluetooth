import Foundation

struct NothingPacket: Equatable, Sendable {
    static let header: [UInt8] = [0x55, 0x60, 0x01]
    static let maximumPayloadLength = Int(UInt16.max)

    let control: UInt16
    let commandID: UInt16
    let sequence: UInt8
    let payload: [UInt8]

    init(control: UInt16 = 0x0160, commandID: UInt16, sequence: UInt8, payload: [UInt8]) {
        self.control = control
        self.commandID = commandID
        self.sequence = sequence
        self.payload = payload
    }

    func encoded() -> [UInt8] {
        guard payload.count <= Self.maximumPayloadLength else { return [] }
        let prefix = [Self.header[0],
                      UInt8(control & 0xFF), UInt8(control >> 8),
                      UInt8(commandID & 0xFF), UInt8(commandID >> 8),
                      UInt8(payload.count & 0xFF), UInt8((payload.count >> 8) & 0xFF),
                      sequence] + payload
        return control & 0x0020 == 0 ? prefix : prefix + CRC16.littleEndianBytes(CRC16.modbus(prefix))
    }
}

struct NothingPacketParser {
    private(set) var rejectedFrameCount = 0
    private var buffer: [UInt8] = []
    private let maximumBufferedBytes = 4096

    mutating func append(_ bytes: [UInt8]) -> [NothingPacket] {
        var packets: [NothingPacket] = []
        var offset = 0
        while offset < bytes.count {
            let end = min(offset + 2048, bytes.count)
            buffer.append(contentsOf: bytes[offset..<end])
            offset = end
            packets.append(contentsOf: drainAvailableFrames())
        }
        return packets
    }

    private mutating func drainAvailableFrames() -> [NothingPacket] {
        var packets: [NothingPacket] = []
        while true {
            guard let headerIndex = findStartOfFrame() else {
                if buffer.last == NothingPacket.header[0] { buffer = [buffer.last!] }
                else { buffer.removeAll(keepingCapacity: true) }
                break
            }
            if headerIndex > 0 { buffer.removeFirst(headerIndex) }
            guard buffer.count >= 8 else { break }
            let control = UInt16(buffer[1]) | (UInt16(buffer[2]) << 8)
            let payloadLength = Int(buffer[5]) | (Int(buffer[6]) << 8)
            guard payloadLength <= maximumBufferedBytes - 10 else {
                rejectedFrameCount += 1
                buffer.removeFirst()
                continue
            }
            let hasCRC = control & 0x0020 != 0
            let frameLength = 8 + payloadLength + (hasCRC ? 2 : 0)
            guard buffer.count >= frameLength else { break }

            let frame = Array(buffer.prefix(frameLength))
            if hasCRC {
                let receivedCRC = UInt16(frame[frameLength - 2]) | (UInt16(frame[frameLength - 1]) << 8)
                // Requests checksum the whole frame; replies from the device checksum the payload only.
                let wholeFrameCRC = CRC16.modbus(frame.dropLast(2))
                let payloadCRC = CRC16.modbus(frame[8..<(frameLength - 2)])
                guard receivedCRC == wholeFrameCRC || receivedCRC == payloadCRC else {
                    rejectedFrameCount += 1
                    buffer.removeFirst()
                    continue
                }
            }

            let commandID = UInt16(frame[3]) | (UInt16(frame[4]) << 8)
            packets.append(NothingPacket(control: control,
                                         commandID: commandID,
                                         sequence: frame[7],
                                         payload: Array(frame[8..<(frameLength - (hasCRC ? 2 : 0))])))
            buffer.removeFirst(frameLength)
        }
        return packets
    }

    private func findStartOfFrame() -> Int? {
        buffer.firstIndex(of: NothingPacket.header[0])
    }
}

extension Sequence where Element == UInt8 {
    var hexString: String { map { String(format: "%02X", $0) }.joined(separator: " ") }
}
