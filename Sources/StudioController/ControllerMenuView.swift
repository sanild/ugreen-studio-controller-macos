import AppKit
import SwiftUI

private let studioAccent = Color(red: 0.10, green: 0.74, blue: 0.38)

struct ControllerMenuView: View {
    @ObservedObject var controller: HeadphoneController
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ambientBackground

            ScrollView {
                glassContent
                    .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 430, height: 700)
        .tint(studioAccent)
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

    private var ambientBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.035 : 0.18),
                    Color.clear,
                    Color.black.opacity(colorScheme == .dark ? 0.10 : 0.025),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var glassContent: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                panelStack
            }
        } else {
            panelStack
        }
    }

    private var panelStack: some View {
        VStack(spacing: 14) {
            header
            connectionNotice
            listeningSection
            soundSection
            buttonSection
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .shadow(color: studioAccent.opacity(0.24), radius: 12, y: 4)

            VStack(alignment: .leading, spacing: 5) {
                Text("Studio Pro")
                    .font(.title3.weight(.semibold))

                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: statusColor.opacity(0.7), radius: 4)

                    Text(controller.status.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let battery = controller.state.battery {
                batteryBadge(battery)
            }
        }
        .padding(16)
        .studioGlass(cornerRadius: 24)
    }

    private func batteryBadge(_ battery: UInt8) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: batteryIcon(for: battery))
                    .foregroundStyle(batteryColor(for: battery))
                Text("\(battery)%")
                    .font(.headline.monospacedDigit())
            }

            ProgressView(value: Double(battery), total: 100)
                .progressViewStyle(.linear)
                .tint(batteryColor(for: battery))
                .frame(width: 72)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            batteryColor(for: battery).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
    }

    @ViewBuilder
    private var connectionNotice: some View {
        if controller.status != .connected {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 9) {
                    Text(connectionHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    reconnectButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .studioGlass(tint: Color.orange.opacity(0.10), cornerRadius: 20)
        }
    }

    @ViewBuilder
    private var reconnectButton: some View {
        if #available(macOS 26.0, *) {
            Button(controller.status == .connecting ? "Connecting…" : "Try Again") {
                controller.connect()
            }
            .buttonStyle(.glassProminent)
            .disabled(controller.status == .connecting)
        } else {
            Button(controller.status == .connecting ? "Connecting…" : "Try Again") {
                controller.connect()
            }
            .buttonStyle(.borderedProminent)
            .disabled(controller.status == .connecting)
        }
    }

    private var listeningSection: some View {
        SectionCard(
            title: "Listening",
            subtitle: "Choose how much of the world gets through",
            systemImage: "waveform"
        ) {
            listeningModeSelector

            if controller.state.listeningMode == .noiseCancellation {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("ANC strength")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(controller.state.ancDepth.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(studioAccent)
                    }

                    Picker("ANC strength", selection: ancDepthBinding) {
                        ForEach(ANCDepth.allCases) { depth in
                            Text(depth.title).tag(depth)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .disabled(!controller.controlsAreEnabled)
        .animation(.snappy(duration: 0.28), value: controller.state.listeningMode)
    }

    @ViewBuilder
    private var listeningModeSelector: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                listeningModeButtons
            }
        } else {
            listeningModeButtons
        }
    }

    private var listeningModeButtons: some View {
        HStack(spacing: 8) {
            ForEach(ListeningMode.allCases) { mode in
                ModeButton(
                    mode: mode,
                    selected: controller.state.listeningMode == mode
                ) {
                    controller.setListeningMode(mode)
                }
            }
        }
    }

    private var soundSection: some View {
        SectionCard(
            title: "Sound",
            subtitle: "Tune playback and headphone feedback",
            systemImage: "slider.horizontal.3"
        ) {
            ControlRow(title: "Equalizer", systemImage: "waveform.path.ecg") {
                Picker("Equalizer", selection: equalizerBinding) {
                    ForEach(EQPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .labelsHidden()
                .frame(width: 155)
            }

            RowDivider()

            ControlRow(title: "Headphone prompts", systemImage: "quote.bubble") {
                Picker("Headphone prompts", selection: promptModeBinding) {
                    ForEach(PromptMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 155)
            }

            RowDivider()
            toggleRow("Spatial audio", systemImage: "dot.radiowaves.left.and.right", binding: spatialAudioBinding)
            toggleRow("Game mode", systemImage: "gamecontroller", binding: gameModeBinding)
            toggleRow("Wind noise reduction", systemImage: "wind", binding: windNoiseBinding)
            toggleRow("Connect two devices", systemImage: "link", binding: dualDeviceBinding)
        }
        .disabled(!controller.controlsAreEnabled)
    }

    private var buttonSection: some View {
        SectionCard(
            title: "Buttons",
            subtitle: "Make the hardware work your way",
            systemImage: "button.programmable"
        ) {
            GroupLabel(title: "ANC button", systemImage: "waveform.circle")
            buttonPicker("Single press", systemImage: "1.circle", slot: .singlePress)
            buttonPicker("Double press", systemImage: "2.circle", slot: .doublePress)
            buttonPicker("Long press", systemImage: "ellipsis.circle", slot: .longPress)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(studioAccent)
                Text("Power-button single press is fixed to Play / Pause. These settings control the separate ANC button.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption)
            .padding(10)
            .background(
                studioAccent.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            RowDivider()

            GroupLabel(title: "Volume buttons", systemImage: "speaker.wave.2")
            actionPicker("Volume + hold", systemImage: "plus.circle", selection: volumeUpBinding)
            actionPicker("Volume − hold", systemImage: "minus.circle", selection: volumeDownBinding)
        }
        .disabled(!controller.controlsAreEnabled)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if let version = controller.state.firmwareVersion {
                    Text("Firmware")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(version)
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                } else if let portPath = controller.portPath {
                    Text(portPath)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
            refreshButton
            quitButton
        }
        .padding(10)
        .padding(.leading, 4)
        .studioGlass(cornerRadius: 18)
    }

    @ViewBuilder
    private var refreshButton: some View {
        if #available(macOS 26.0, *) {
            Button {
                controller.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glass)
            .disabled(!controller.controlsAreEnabled)
        } else {
            Button("Refresh") {
                controller.refresh()
            }
            .disabled(!controller.controlsAreEnabled)
        }
    }

    @ViewBuilder
    private var quitButton: some View {
        if #available(macOS 26.0, *) {
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.glass)
            .help("Quit Studio Controller")
        } else {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func toggleRow(
        _ title: String,
        systemImage: String,
        binding: Binding<Bool>
    ) -> some View {
        ControlRow(title: title, systemImage: systemImage) {
            Toggle(title, isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private func buttonPicker(
        _ title: String,
        systemImage: String,
        slot: ANCButtonSlot
    ) -> some View {
        ControlRow(title: title, systemImage: systemImage) {
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
            .labelsHidden()
            .frame(width: 175)
        }
    }

    private func actionPicker(
        _ title: String,
        systemImage: String,
        selection: Binding<VolumeButtonAction>
    ) -> some View {
        ControlRow(title: title, systemImage: systemImage) {
            Picker(title, selection: selection) {
                ForEach(VolumeButtonAction.allCases) { action in
                    Text(action.title).tag(action)
                }
            }
            .labelsHidden()
            .frame(width: 175)
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
            return "The control channel opened, but Studio Pro did not answer. Keep the headphones powered on and connected, then try again."
        case .unavailable:
            return "Pair UGREEN Studio Pro in System Settings → Bluetooth, then try again."
        case let .failed(message):
            return message
        default:
            return "Opening Studio Pro’s direct Bluetooth control channel. Your audio connection can stay active."
        }
    }

    private var statusColor: Color {
        switch controller.status {
        case .connected:
            return studioAccent
        case .connecting:
            return .orange
        default:
            return .red
        }
    }

    private func batteryColor(for battery: UInt8) -> Color {
        switch battery {
        case 21...:
            return studioAccent
        case 11...:
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

private struct ModeButton: View {
    let mode: ListeningMode
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .symbolRenderingMode(.hierarchical)

                Text(mode.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(selected ? studioAccent : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .studioGlass(
                tint: selected ? studioAccent.opacity(0.22) : nil,
                cornerRadius: 16,
                interactive: true
            )
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(studioAccent.opacity(0.55), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(studioAccent)
                    .frame(width: 30, height: 30)
                    .background(
                        studioAccent.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .studioGlass(cornerRadius: 22)
    }
}

private struct ControlRow<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 21)

            Text(title)
                .font(.callout)

            Spacer(minLength: 8)
            content
        }
        .frame(minHeight: 30)
    }
}

private struct GroupLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 1)
    }
}

private struct RowDivider: View {
    var body: some View {
        Divider()
            .opacity(0.45)
            .padding(.leading, 31)
    }
}

private extension View {
    @ViewBuilder
    func studioGlass(
        tint: Color? = nil,
        cornerRadius: CGFloat,
        interactive: Bool = false
    ) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(
                .regular.tint(tint).interactive(interactive),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
    }
}

private extension ListeningMode {
    var systemImage: String {
        switch self {
        case .noiseCancellation:
            return "waveform.badge.minus"
        case .off:
            return "speaker.slash"
        case .ambient:
            return "ear"
        }
    }
}
