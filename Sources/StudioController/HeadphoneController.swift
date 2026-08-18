import Foundation
import OSLog

@MainActor
final class HeadphoneController: ObservableObject {
    private static let logger = Logger(
        subsystem: "dev.studiocontroller.mac",
        category: "headphones"
    )

    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case noResponse
        case unavailable
        case failed(String)

        var label: String {
            switch self {
            case .disconnected:
                return "Disconnected"
            case .connecting:
                return "Connecting…"
            case .connected:
                return "Connected"
            case .noResponse:
                return "Control channel unavailable"
            case .unavailable:
                return "Not paired"
            case let .failed(message):
                return message
            }
        }
    }

    @Published private(set) var status: ConnectionStatus = .disconnected
    @Published private(set) var state = HeadphoneState()
    @Published private(set) var portPath: String?

    private let transport = RFCOMMTransport()
    private var receiveBuffer = Data()
    private var connectionGeneration = 0

    init() {
        transport.onData = { [weak self] data in
            Task { @MainActor in
                self?.receive(data)
            }
        }
        transport.onError = { [weak self] error in
            Task { @MainActor in
                self?.status = .failed(error.localizedDescription)
            }
        }
        Task { @MainActor [weak self] in
            self?.connect()
        }
    }

    var controlsAreEnabled: Bool {
        status == .connected
    }

    func connect() {
        connectionGeneration += 1
        let generation = connectionGeneration
        receiveBuffer.removeAll(keepingCapacity: true)
        status = .connecting

        transport.connect { [weak self] result in
            guard let self, generation == self.connectionGeneration else { return }
            switch result {
            case let .success(path):
                self.portPath = path
                self.scheduleQueries(generation: generation)
            case let .failure(error):
                if case RFCOMMTransport.TransportError.deviceUnavailable = error {
                    self.status = .unavailable
                } else {
                    self.status = .failed(error.localizedDescription)
                }
            }
        }
    }

    func disconnect() {
        connectionGeneration += 1
        transport.disconnect()
        status = .disconnected
    }

    func refresh() {
        guard status == .connected || status == .connecting || status == .noResponse else { return }
        send(UGREENProtocol.deviceInfoQuery)
        send(UGREENProtocol.firmwareVersionQuery)
    }

    func setListeningMode(_ mode: ListeningMode) {
        guard controlsAreEnabled else { return }
        state.listeningMode = mode
        let value = state.ancDepth.encoded(for: mode)
        sendSetting(.noiseControl, payload: [value])
    }

    func setANCDepth(_ depth: ANCDepth) {
        guard controlsAreEnabled else { return }
        state.ancDepth = depth
        state.listeningMode = .noiseCancellation
        sendSetting(.noiseControl, payload: [depth.encoded(for: .noiseCancellation)])
    }

    func setEqualizer(_ equalizer: EQPreset) {
        guard controlsAreEnabled else { return }
        state.equalizer = equalizer
        sendSetting(.equalizer, payload: [equalizer.rawValue])
    }

    func setPromptMode(_ mode: PromptMode) {
        guard controlsAreEnabled else { return }
        state.promptMode = mode
        sendSetting(.promptMode, payload: [mode.rawValue])
    }

    func setGameMode(_ enabled: Bool) {
        guard controlsAreEnabled else { return }
        state.gameMode = enabled
        sendSetting(.gameMode, payload: [enabled ? 1 : 0])
    }

    func setSpatialAudio(_ enabled: Bool) {
        guard controlsAreEnabled else { return }
        state.spatialAudio = enabled
        sendSetting(.spatialAudio, payload: [enabled ? 1 : 0])
    }

    func setDualDevice(_ enabled: Bool) {
        guard controlsAreEnabled else { return }
        state.dualDevice = enabled
        sendSetting(.dualDevice, payload: [enabled ? 1 : 0])
    }

    func setWindNoiseReduction(_ enabled: Bool) {
        guard controlsAreEnabled else { return }
        state.windNoiseReduction = enabled
        sendSetting(.windNoiseReduction, payload: [enabled ? 1 : 0])
    }

    func setANCButton(_ slot: ANCButtonSlot, action: ANCButtonAction) {
        guard controlsAreEnabled else { return }
        state.ancButtonActions[slot.rawValue] = action.rawValue
        sendSetting(.buttonControl, payload: state.ancButtonActions)
    }

    func setVolumeUpAction(_ action: VolumeButtonAction) {
        guard controlsAreEnabled else { return }
        state.volumeUpAction = action
        sendSetting(.volumeUpAction, payload: [action.rawValue])
    }

    func setVolumeDownAction(_ action: VolumeButtonAction) {
        guard controlsAreEnabled else { return }
        state.volumeDownAction = action
        sendSetting(.volumeDownAction, payload: [action.rawValue])
    }

    private func scheduleQueries(generation: Int) {
        for delay in [0.75, 2.0, 3.5] {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self,
                      generation == self.connectionGeneration,
                      self.status == .connecting else { return }
                self.refresh()
            }
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5.5))
            guard let self,
                  generation == self.connectionGeneration,
                  self.status == .connecting else { return }
            self.status = .noResponse
        }
    }

    private func sendSetting(_ instruction: UGREENProtocol.Instruction, payload: [UInt8]) {
        guard controlsAreEnabled else { return }
        send(UGREENProtocol.packet(instruction: instruction, payload: payload))
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            self?.refresh()
        }
    }

    private func send(_ data: Data) {
        transport.send(data) { [weak self] result in
            if case let .failure(error) = result {
                self?.status = .failed(error.localizedDescription)
            }
        }
    }

    private func receive(_ data: Data) {
        receiveBuffer.append(data)
        let frames = UGREENProtocol.consumeResponseFrames(from: &receiveBuffer)
        let validFrames = frames.filter(\.succeeded)
        guard !validFrames.isEmpty else { return }

        status = .connected
        Self.logger.info(
            "Connected to UGREEN Studio Pro; received \(validFrames.count, privacy: .public) response frame(s)"
        )
        for frame in validFrames {
            apply(frame)
        }
    }

    private func apply(_ frame: UGREENProtocol.ResponseFrame) {
        switch frame.instruction {
        case UGREENProtocol.Instruction.deviceInfo.rawValue:
            state.applyDeviceInfo(frame.payload)
        case UGREENProtocol.Instruction.firmwareVersion.rawValue:
            let primary = Array(frame.payload.prefix(3))
            let secondary = frame.payload.count >= 6 ? Array(frame.payload[3..<6]) : []
            let version = primary.contains(where: { $0 != 0 }) ? primary : secondary
            if version.count == 3 {
                state.firmwareVersion = version.map(String.init).joined(separator: ".")
            }
        case UGREENProtocol.Instruction.equalizer.rawValue:
            if let rawValue = frame.payload.first, let preset = EQPreset(rawValue: rawValue) {
                state.equalizer = preset
            }
        case UGREENProtocol.Instruction.dualDevice.rawValue:
            state.dualDevice = frame.payload.first.map { $0 != 0 } ?? state.dualDevice
        case UGREENProtocol.Instruction.noiseControl.rawValue:
            if let rawValue = frame.payload.first {
                state.ancDepth = ANCDepth.decode(rawValue)
                state.listeningMode = rawValue % 16 == 1
                    ? .noiseCancellation
                    : (rawValue % 16 == 2 ? .ambient : .off)
            }
        case UGREENProtocol.Instruction.promptMode.rawValue:
            if let rawValue = frame.payload.first, let mode = PromptMode(rawValue: rawValue) {
                state.promptMode = mode
            }
        case UGREENProtocol.Instruction.spatialAudio.rawValue:
            state.spatialAudio = frame.payload.first.map { $0 != 0 } ?? state.spatialAudio
        default:
            break
        }
    }
}
