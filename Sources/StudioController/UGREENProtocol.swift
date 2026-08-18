import Foundation

enum UGREENProtocol {
    enum Instruction: UInt8 {
        case firmwareVersion = 1
        case deviceInfo = 4
        case equalizer = 5
        case dualDevice = 6
        case gameMode = 8
        case noiseControl = 9
        case buttonControl = 10
        case promptMode = 12
        case spatialAudio = 18
        case volumeUpAction = 20
        case volumeDownAction = 21
        case windNoiseReduction = 23
    }

    struct ResponseFrame: Equatable {
        let instruction: UInt8
        let succeeded: Bool
        let payload: [UInt8]
    }

    private static let requestHeader: [UInt8] = [0xAA, 0xBB, 0xCC]
    private static let responseHeader: [UInt8] = [0xDD, 0xEE, 0xFF]

    static func packet(instruction: Instruction, payload: [UInt8]) -> Data {
        precondition(payload.count <= UInt8.max)

        let body = [instruction.rawValue, UInt8(payload.count)] + payload
        let checksum = crc16(body)
        return Data(requestHeader + body + [UInt8(checksum & 0xFF), UInt8(checksum >> 8)])
    }

    static var deviceInfoQuery: Data {
        packet(instruction: .deviceInfo, payload: [0])
    }

    static var firmwareVersionQuery: Data {
        packet(instruction: .firmwareVersion, payload: [0])
    }

    static func crc16(_ bytes: [UInt8]) -> UInt16 {
        var checksum: UInt16 = 0xFFFF
        for byte in bytes {
            checksum ^= UInt16(byte)
            for _ in 0..<8 {
                if checksum & 1 == 1 {
                    checksum = (checksum >> 1) ^ 0xA001
                } else {
                    checksum >>= 1
                }
            }
        }
        return checksum
    }

    static func consumeResponseFrames(from buffer: inout Data) -> [ResponseFrame] {
        var bytes = [UInt8](buffer)
        var frames: [ResponseFrame] = []

        while bytes.count >= 6 {
            guard let headerIndex = findResponseHeader(in: bytes) else {
                bytes = Array(bytes.suffix(2))
                break
            }

            if headerIndex > 0 {
                bytes.removeFirst(headerIndex)
            }
            guard bytes.count >= 6 else { break }

            let payloadLength = Int(bytes[5])
            let frameLength = 8 + payloadLength
            guard frameLength <= 263 else {
                bytes.removeFirst()
                continue
            }
            guard bytes.count >= frameLength else { break }

            let rawFrame = Array(bytes.prefix(frameLength))
            let payload = Array(rawFrame[6..<(6 + payloadLength)])
            frames.append(
                ResponseFrame(
                    instruction: rawFrame[3],
                    succeeded: rawFrame[4] != 0,
                    payload: payload
                )
            )
            bytes.removeFirst(frameLength)
        }

        buffer = Data(bytes)
        return frames
    }

    private static func findResponseHeader(in bytes: [UInt8]) -> Int? {
        guard bytes.count >= responseHeader.count else { return nil }
        return (0...(bytes.count - responseHeader.count)).first { index in
            Array(bytes[index..<(index + responseHeader.count)]) == responseHeader
        }
    }
}
