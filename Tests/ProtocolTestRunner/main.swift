import Foundation

private var failures = 0

private func expect<T: Equatable>(
    _ actual: @autoclosure () -> T,
    _ expected: T,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let actualValue = actual()
    guard actualValue != expected else { return }
    failures += 1
    print("FAIL \(file):\(line): \(message) — got \(actualValue), expected \(expected)")
}

private func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard !condition() else { return }
    failures += 1
    print("FAIL \(file):\(line): \(message)")
}

private func testDeviceInfoQuery() {
    expect(
        [UInt8](UGREENProtocol.deviceInfoQuery),
        [0xAA, 0xBB, 0xCC, 0x04, 0x01, 0x00, 0x31, 0x91],
        "device-info query must match the recovered wire packet"
    )
}

private func testNoiseModeEncoding() {
    expect(ANCDepth.ultra.encoded(for: .noiseCancellation), 161, "ultra ANC encoding")
    expect(ANCDepth.ultra.encoded(for: .off), 160, "ultra/off encoding")
    expect(ANCDepth.ultra.encoded(for: .ambient), 162, "ultra/ambient encoding")
    expect(ANCDepth.adaptive.encoded(for: .noiseCancellation), 209, "adaptive ANC encoding")
    expect(ANCDepth.decode(194), .gentle, "gentle/ambient decoding")
}

private func testFragmentedResponse() {
    var payload = [UInt8](repeating: 0, count: 26)
    payload[0] = 84
    payload[3] = 177
    payload[4] = EQPreset.bass.rawValue
    payload[5] = 1
    payload[6] = 1
    payload[8] = ANCButtonAction.noiseControl.rawValue
    payload[9] = ANCButtonAction.gameMode.rawValue
    payload[11] = ANCButtonAction.spatialAudio.rawValue
    payload[16] = PromptMode.englishVoice.rawValue
    payload[20] = 1
    payload[22] = VolumeButtonAction.previousTrack.rawValue
    payload[23] = VolumeButtonAction.nextTrack.rawValue
    payload[25] = 1

    let body = [UInt8(4), UInt8(1), UInt8(payload.count)] + payload
    let checksum = UGREENProtocol.crc16(body)
    let rawFrame = [UInt8(0xDD), 0xEE, 0xFF] + body + [
        UInt8(checksum & 0xFF),
        UInt8(checksum >> 8),
    ]

    var buffer = Data(rawFrame.prefix(9))
    expect(UGREENProtocol.consumeResponseFrames(from: &buffer).isEmpty, "partial frame must wait")
    buffer.append(contentsOf: rawFrame.dropFirst(9))

    let frames = UGREENProtocol.consumeResponseFrames(from: &buffer)
    expect(frames.count, 1, "one complete response should be parsed")
    guard let frame = frames.first else { return }

    var state = HeadphoneState()
    state.applyDeviceInfo(frame.payload)
    expect(state.battery, 84, "battery parsing")
    expect(state.listeningMode, .noiseCancellation, "listening-mode parsing")
    expect(state.ancDepth, .general, "ANC-depth parsing")
    expect(state.equalizer, .bass, "EQ parsing")
    expect(state.dualDevice, "dual-device parsing")
    expect(state.gameMode, "game-mode parsing")
    expect(state.promptMode, .englishVoice, "prompt-mode parsing")
    expect(state.spatialAudio, "spatial-audio parsing")
    expect(state.windNoiseReduction, "wind-reduction parsing")
    expect(state.ancButtonAction(for: .singlePress), .noiseControl, "button mapping parsing")
    expect(state.volumeUpAction, .previousTrack, "volume-up mapping parsing")
    expect(state.volumeDownAction, .nextTrack, "volume-down mapping parsing")
}

private func testPromptModePacket() {
    let packet = [UInt8](
        UGREENProtocol.packet(instruction: .promptMode, payload: [PromptMode.englishVoice.rawValue])
    )
    expect(Array(packet.prefix(6)), [0xAA, 0xBB, 0xCC, 12, 1, 0], "English-prompt packet")

    let beepPacket = [UInt8](
        UGREENProtocol.packet(instruction: .promptMode, payload: [PromptMode.beepsOnly.rawValue])
    )
    expect(Array(beepPacket.prefix(6)), [0xAA, 0xBB, 0xCC, 12, 1, 2], "beep-only packet")
}

private func testButtonPacket() {
    let mappings: [UInt8] = [8, 7, 0, 11, 0, 0, 0, 0]
    let packet = [UInt8](UGREENProtocol.packet(instruction: .buttonControl, payload: mappings))
    expect(Array(packet.prefix(5)), [0xAA, 0xBB, 0xCC, 10, 8], "button packet header")
    expect(Array(packet[5..<13]), mappings, "button packet payload")
}

private func testCapturedStudioProResponse() {
    let bytes: [UInt8] = [
        0xDD, 0xEE, 0xFF, 0x04, 0x01, 0x1E, 0x14, 0xFF, 0xFF, 0xA0,
        0x00, 0x01, 0x00, 0x00, 0x08, 0x0B, 0x00, 0x07, 0x00, 0x00,
        0x00, 0x00, 0x02, 0x00, 0x00, 0x09, 0x00, 0x00, 0x04, 0x05,
        0x00, 0x00, 0x00, 0x0C, 0x0D, 0x0E, 0xD0, 0xE3,
    ]
    var buffer = Data(bytes)
    let frames = UGREENProtocol.consumeResponseFrames(from: &buffer)

    expect(frames.count, 1, "captured hardware response should parse")
    guard let frame = frames.first else { return }
    expect(frame.succeeded, "captured hardware response state")

    var state = HeadphoneState()
    state.applyDeviceInfo(frame.payload)
    expect(state.battery, 20, "captured battery value")
    expect(state.listeningMode, .off, "captured listening mode")
    expect(state.dualDevice, "captured dual-device state")
    expect(state.promptMode, .beepsOnly, "captured prompt mode")
    expect(state.ancButtonAction(for: .singlePress), .noiseControl, "captured single press")
    expect(state.ancButtonAction(for: .doublePress), .spatialAudio, "captured double press")
    expect(state.ancButtonAction(for: .longPress), .gameMode, "captured long press")
    expect(state.volumeUpAction, .nextTrack, "captured volume-up action")
    expect(state.volumeDownAction, .previousTrack, "captured volume-down action")
}

testDeviceInfoQuery()
testNoiseModeEncoding()
testFragmentedResponse()
testButtonPacket()
testPromptModePacket()
testCapturedStudioProResponse()

if failures == 0 {
    print("All Studio Controller protocol tests passed.")
} else {
    print("\(failures) protocol test(s) failed.")
    exit(1)
}
