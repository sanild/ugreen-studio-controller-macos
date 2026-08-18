import Foundation
import IOBluetooth

final class RFCOMMTransport: NSObject, IOBluetoothRFCOMMChannelDelegate {
    enum TransportError: LocalizedError {
        case deviceUnavailable
        case openRequestFailed(IOReturn)
        case openFailed(IOReturn)
        case openTimedOut
        case notConnected
        case writeFailed(IOReturn)

        var errorDescription: String? {
            switch self {
            case .deviceUnavailable:
                return "UGREEN Studio Pro is not paired with this Mac."
            case let .openRequestFailed(code):
                return "macOS rejected the Bluetooth control request (\(Self.hex(code)))."
            case let .openFailed(code):
                return "Studio Pro rejected the Bluetooth control channel (\(Self.hex(code)))."
            case .openTimedOut:
                return "macOS timed out while opening Studio Pro’s Bluetooth control channel."
            case .notConnected:
                return "The Studio Pro control channel is not open."
            case let .writeFailed(code):
                return "The command could not be sent (\(Self.hex(code)))."
            }
        }

        private static func hex(_ code: IOReturn) -> String {
            String(format: "0x%08X", code)
        }
    }

    var onData: ((Data) -> Void)?
    var onError: ((Error) -> Void)?

    private static let modelName = "UGREEN Studio Pro"
    private static let channelID: BluetoothRFCOMMChannelID = 1
    private static let frameworkWarmupDelay = 2.0

    private let writeQueue = DispatchQueue(label: "dev.studiocontroller.rfcomm.write")
    private var channel: IOBluetoothRFCOMMChannel?
    private var device: IOBluetoothDevice?
    private var pendingCompletion: ((Result<String, Error>) -> Void)?
    private var connectGeneration = 0

    func connect(completion: @escaping (Result<String, Error>) -> Void) {
        precondition(Thread.isMainThread)
        connectGeneration += 1
        let generation = connectGeneration
        closeChannel()

        guard let device = Self.pairedStudioPro() else {
            completion(.failure(TransportError.deviceUnavailable))
            return
        }

        self.device = device
        pendingCompletion = completion

        // On current macOS releases IOBluetooth initially reports powered-on before
        // its internal classic coordinator is ready. Opening RFCOMM in that window
        // is silently discarded, so let its run loop settle before requesting CID 1.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.frameworkWarmupDelay) { [weak self] in
            guard let self, generation == self.connectGeneration else { return }

            var newChannel: IOBluetoothRFCOMMChannel?
            let result = device.openRFCOMMChannelAsync(
                &newChannel,
                withChannelID: Self.channelID,
                delegate: self
            )
            self.channel = newChannel

            guard result == kIOReturnSuccess else {
                self.finishConnection(.failure(TransportError.openRequestFailed(result)))
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                guard let self,
                      generation == self.connectGeneration,
                      self.pendingCompletion != nil else { return }
                self.closeChannel()
                self.finishConnection(.failure(TransportError.openTimedOut))
            }
        }
    }

    func send(_ data: Data, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let channel, channel.isOpen() else {
            completion?(.failure(TransportError.notConnected))
            return
        }

        writeQueue.async {
            var bytes = [UInt8](data)
            let result = bytes.withUnsafeMutableBytes { buffer in
                channel.writeSync(buffer.baseAddress, length: UInt16(buffer.count))
            }
            DispatchQueue.main.async {
                if result == kIOReturnSuccess {
                    completion?(.success(()))
                } else {
                    completion?(.failure(TransportError.writeFailed(result)))
                }
            }
        }
    }

    func disconnect() {
        precondition(Thread.isMainThread)
        connectGeneration += 1
        pendingCompletion = nil
        closeChannel()
    }

    func rfcommChannelOpenComplete(
        _ rfcommChannel: IOBluetoothRFCOMMChannel!,
        status error: IOReturn
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard error == kIOReturnSuccess, rfcommChannel.isOpen() else {
                self.finishConnection(.failure(TransportError.openFailed(error)))
                return
            }

            self.channel = rfcommChannel
            self.finishConnection(.success("Bluetooth RFCOMM channel 1"))
        }
    }

    func rfcommChannelData(
        _ rfcommChannel: IOBluetoothRFCOMMChannel!,
        data dataPointer: UnsafeMutableRawPointer!,
        length dataLength: Int
    ) {
        guard let dataPointer, dataLength > 0 else { return }
        let data = Data(bytes: dataPointer, count: dataLength)
        onData?(data)
    }

    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.channel === rfcommChannel else { return }
            self.channel = nil
            self.onError?(TransportError.notConnected)
        }
    }

    private static func pairedStudioPro() -> IOBluetoothDevice? {
        (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice])?.first { device in
            device.name?.caseInsensitiveCompare(modelName) == .orderedSame
        }
    }

    private func finishConnection(_ result: Result<String, Error>) {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(result)
    }

    private func closeChannel() {
        if let channel {
            self.channel = nil
            _ = channel.close()
        }
        device = nil
    }
}
