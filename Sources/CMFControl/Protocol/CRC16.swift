import Foundation

enum CRC16 {
    static func modbus(_ bytes: some Sequence<UInt8>) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xA001 : crc >> 1
            }
        }
        return crc
    }

    static func littleEndianBytes(_ value: UInt16) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8(value >> 8)]
    }
}
