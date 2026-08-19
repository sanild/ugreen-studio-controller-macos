import AppKit
import SwiftUI

struct ControllerMenuView: View {
    @ObservedObject var controller: HeadphoneController

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                connectionNotice

                SectionCard(title: "Listening mode", systemImage: "waveform") {
                    Picker("Listening mode", selection: listeningModeBinding) {
                        ForEach(ListeningMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if controller.state.listeningMode == .noiseCancellation {
                        Picker("ANC strength", selection: ancDepthBinding) {
                            ForEach(ANCDepth.allCases) { depth in
                                Text(depth.title).tag(depth)
                            }
                        }
                    }
                }
                .disabled(!controller.controlsAreEnabled)

                SectionCard(title: "Sound", systemImage: "slider.horizontal.3") {
                    Picker("Equalizer", selection: equalizerBinding) {
                        ForEach(EQPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }

                    Picker("Headphone prompts", selection: promptModeBinding) {
                        ForEach(PromptMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Toggle("Spatial audio", isOn: spatialAudioBinding)
                    Toggle("Game mode", isOn: gameModeBinding)
                    Toggle("Wind noise reduction", isOn: windNoiseBinding)
                    Toggle("Connect two devices", isOn: dualDeviceBinding)
                }
                .disabled(!controller.controlsAreEnabled)

                SectionCard(title: "Button controls", systemImage: "button.programmable") {
                    Text("ANC button")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    buttonPicker("Single press", slot: .singlePress)
                    buttonPicker("Double press", slot: .doublePress)
                    buttonPicker("Long press", slot: .longPress)

                    Text("The power button’s single press is fixed to Play / Pause. These settings control the separate ANC button.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    Picker("Volume + hold", selection: volumeUpBinding) {
                        ForEach(VolumeButtonAction.allCases) { action in
                            Text(action.title).tag(action)
                        }
                    }
                    Picker("Volume − hold", selection: volumeDownBinding) {
                        ForEach(VolumeButtonAction.allCases) { action in
                            Text(action.title).tag(action)
                        }
                    }
                }
                .disabled(!controller.controlsAreEnabled)

                footer
            }
            .padding(16)
        }
        .frame(width: 390, height: 650)
        .onAppear {
            switch controller.status {
            case .connected:
                controller.refresh()
            case .connecting:
                break
            default:
                controller.connect()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("UGREEN Studio Pro")
                    .font(.headline)
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(controller.status.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let battery = controller.state.battery {
                Label("\(battery)%", systemImage: batteryIcon(for: battery))
                    .font(.callout.monospacedDigit())
            }
        }
    }

    @ViewBuilder
    private var connectionNotice: some View {
        if controller.status != .connected {
            VStack(alignment: .leading, spacing: 8) {
                Text(connectionHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(controller.status == .connecting ? "Connecting…" : "Retry connection") {
                    controller.connect()
                }
                .buttonStyle(.borderedProminent)
                .disabled(controller.status == .connecting)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Divider()
            HStack {
                if let version = controller.state.firmwareVersion {
                    Text("Firmware \(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let portPath = controller.portPath {
                    Text(portPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Refresh") {
                    controller.refresh()
                }
                .disabled(!controller.controlsAreEnabled)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private func buttonPicker(_ title: String, slot: ANCButtonSlot) -> some View {
        Picker(
            title,
            selection: Binding(
                get: { controller.state.ancButtonAction(for: slot) },
                set: { controller.setANCButton(slot, action: $0) }
            )
        ) {
            ForEach(ANCButtonAction.allCases) { action in
                Text(action.title).tag(action)
            }
        }
    }

    private var listeningModeBinding: Binding<ListeningMode> {
        Binding(
            get: { controller.state.listeningMode },
            set: { controller.setListeningMode($0) }
        )
    }

    private var ancDepthBinding: Binding<ANCDepth> {
        Binding(
            get: { controller.state.ancDepth },
            set: { controller.setANCDepth($0) }
        )
    }

    private var equalizerBinding: Binding<EQPreset> {
        Binding(
            get: { controller.state.equalizer },
            set: { controller.setEqualizer($0) }
        )
    }

    private var promptModeBinding: Binding<PromptMode> {
        Binding(
            get: { controller.state.promptMode },
            set: { controller.setPromptMode($0) }
        )
    }

    private var gameModeBinding: Binding<Bool> {
        Binding(
            get: { controller.state.gameMode },
            set: { controller.setGameMode($0) }
        )
    }

    private var spatialAudioBinding: Binding<Bool> {
        Binding(
            get: { controller.state.spatialAudio },
            set: { controller.setSpatialAudio($0) }
        )
    }

    private var windNoiseBinding: Binding<Bool> {
        Binding(
            get: { controller.state.windNoiseReduction },
            set: { controller.setWindNoiseReduction($0) }
        )
    }

    private var dualDeviceBinding: Binding<Bool> {
        Binding(
            get: { controller.state.dualDevice },
            set: { controller.setDualDevice($0) }
        )
    }

    private var volumeUpBinding: Binding<VolumeButtonAction> {
        Binding(
            get: { controller.state.volumeUpAction },
            set: { controller.setVolumeUpAction($0) }
        )
    }

    private var volumeDownBinding: Binding<VolumeButtonAction> {
        Binding(
            get: { controller.state.volumeDownAction },
            set: { controller.setVolumeDownAction($0) }
        )
    }

    private var connectionHelpText: String {
        switch controller.status {
        case .noResponse:
            return "The Bluetooth control channel opened, but Studio Pro did not answer. Keep the headphones powered on and connected, then retry."
        case .unavailable:
            return "Pair UGREEN Studio Pro in System Settings → Bluetooth, then reopen this menu."
        case let .failed(message):
            return message
        default:
            return "Opening Studio Pro’s direct Bluetooth control channel. Audio can stay connected."
        }
    }

    private var statusColor: Color {
        switch controller.status {
        case .connected:
            return .green
        case .connecting:
            return .orange
        default:
            return .red
        }
    }

    private func batteryIcon(for battery: UInt8) -> String {
        switch battery {
        case 76...:
            return "battery.100percent"
        case 51...:
            return "battery.75percent"
        case 26...:
            return "battery.50percent"
        case 11...:
            return "battery.25percent"
        default:
            return "battery.0percent"
        }
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
