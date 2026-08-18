import Foundation

enum ListeningMode: String, CaseIterable, Identifiable {
    case noiseCancellation
    case off
    case ambient

    var id: Self { self }

    var title: String {
        switch self {
        case .noiseCancellation:
            return "ANC"
        case .off:
            return "Off"
        case .ambient:
            return "Ambient"
        }
    }
}

enum ANCDepth: UInt8, CaseIterable, Identifiable {
    case ultra = 161
    case general = 177
    case gentle = 193
    case adaptive = 209

    var id: Self { self }

    var title: String {
        switch self {
        case .ultra:
            return "Ultra"
        case .general:
            return "General"
        case .gentle:
            return "Gentle"
        case .adaptive:
            return "Adaptive"
        }
    }

    static func decode(_ rawValue: UInt8) -> ANCDepth {
        let normalized = rawValue - (rawValue % 16)
        switch normalized {
        case 160:
            return .ultra
        case 176:
            return .general
        case 192:
            return .gentle
        case 208:
            return .adaptive
        default:
            return .ultra
        }
    }

    func encoded(for mode: ListeningMode) -> UInt8 {
        switch mode {
        case .noiseCancellation:
            return rawValue
        case .off:
            return rawValue - 1
        case .ambient:
            return rawValue + 1
        }
    }
}

enum EQPreset: UInt8, CaseIterable, Identifiable {
    case classic = 0
    case jazz
    case electronic
    case pop
    case classical
    case rock
    case bass
    case treble

    var id: Self { self }

    var title: String {
        switch self {
        case .classic:
            return "Classic"
        case .jazz:
            return "Jazz"
        case .electronic:
            return "Electronic"
        case .pop:
            return "Pop"
        case .classical:
            return "Classical"
        case .rock:
            return "Rock"
        case .bass:
            return "Bass"
        case .treble:
            return "Treble"
        }
    }
}

enum PromptMode: UInt8, CaseIterable, Identifiable {
    case englishVoice = 0
    case beepsOnly = 2

    var id: Self { self }

    var title: String {
        switch self {
        case .englishVoice:
            return "English voice"
        case .beepsOnly:
            return "Beeps only"
        }
    }
}

enum ANCButtonAction: UInt8, CaseIterable, Identifiable {
    case none = 0
    case gameMode = 7
    case noiseControl = 8
    case spatialAudio = 11

    var id: Self { self }

    var title: String {
        switch self {
        case .none:
            return "None"
        case .gameMode:
            return "Game / Music mode"
        case .noiseControl:
            return "Noise control"
        case .spatialAudio:
            return "Spatial / Music mode"
        }
    }
}

enum VolumeButtonAction: UInt8, CaseIterable, Identifiable {
    case none = 0
    case nextTrack = 4
    case previousTrack = 5

    var id: Self { self }

    var title: String {
        switch self {
        case .none:
            return "None"
        case .nextTrack:
            return "Next track"
        case .previousTrack:
            return "Previous track"
        }
    }
}

enum ANCButtonSlot: Int {
    case singlePress = 0
    case doublePress = 1
    case longPress = 3
}

struct HeadphoneState: Equatable {
    var battery: UInt8?
    var firmwareVersion: String?
    var listeningMode: ListeningMode = .off
    var ancDepth: ANCDepth = .ultra
    var equalizer: EQPreset = .classic
    var dualDevice = false
    var gameMode = false
    var highQualityAudio = false
    var spatialAudio = false
    var windNoiseReduction = false
    var promptMode: PromptMode = .beepsOnly
    var ancButtonActions = [UInt8](repeating: 0, count: 8)
    var volumeUpAction: VolumeButtonAction = .none
    var volumeDownAction: VolumeButtonAction = .none

    mutating func applyDeviceInfo(_ payload: [UInt8]) {
        if let rawBattery = payload[safe: 0], rawBattery > 0, rawBattery < 255 {
            battery = min(rawBattery, 100)
        }

        if let rawNoiseMode = payload[safe: 3] {
            ancDepth = ANCDepth.decode(rawNoiseMode)
            switch rawNoiseMode % 16 {
            case 1:
                listeningMode = .noiseCancellation
            case 2:
                listeningMode = .ambient
            default:
                listeningMode = .off
            }
        }

        if let rawEQ = payload[safe: 4], let preset = EQPreset(rawValue: rawEQ) {
            equalizer = preset
        }

        dualDevice = payload[safe: 5].map { $0 != 0 } ?? dualDevice
        gameMode = payload[safe: 6].map { $0 != 0 } ?? gameMode
        highQualityAudio = payload[safe: 7].map { $0 != 0 } ?? highQualityAudio

        if payload.count >= 16 {
            ancButtonActions = Array(payload[8..<16])
        }

        if let rawPromptMode = payload[safe: 16], let mode = PromptMode(rawValue: rawPromptMode) {
            promptMode = mode
        }

        spatialAudio = payload[safe: 20].map { $0 != 0 } ?? spatialAudio

        if let rawVolumeUp = payload[safe: 22], let action = VolumeButtonAction(rawValue: rawVolumeUp) {
            volumeUpAction = action
        }
        if let rawVolumeDown = payload[safe: 23], let action = VolumeButtonAction(rawValue: rawVolumeDown) {
            volumeDownAction = action
        }

        windNoiseReduction = payload[safe: 25].map { $0 != 0 } ?? windNoiseReduction
    }

    func ancButtonAction(for slot: ANCButtonSlot) -> ANCButtonAction {
        guard let rawValue = ancButtonActions[safe: slot.rawValue] else {
            return .none
        }
        return ANCButtonAction(rawValue: rawValue) ?? .none
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
