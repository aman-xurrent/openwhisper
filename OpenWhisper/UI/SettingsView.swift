import SwiftUI

struct SettingsView: View {
    var preferences: Preferences
    var modelStore: ModelStore
    var selection: SettingsSelection
    let hotKeyCenter: HotKeyCenter

    var body: some View {
        TabView(selection: Bindable(selection).tab) {
            GeneralSettingsView(preferences: preferences, hotKeyCenter: hotKeyCenter)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            ModelSettingsView(preferences: preferences, modelStore: modelStore)
                .tabItem { Label("Model", systemImage: "waveform") }
                .tag(SettingsTab.model)
            CorrectionSettingsView(preferences: preferences, modelStore: modelStore)
                .tabItem { Label("Correction", systemImage: "text.badge.checkmark") }
                .tag(SettingsTab.correction)
            PermissionsSettingsView()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
                .tag(SettingsTab.permissions)
        }
        .frame(width: SettingsWindowController.contentSize.width, height: SettingsWindowController.contentSize.height)
    }
}

struct GeneralSettingsView: View {
    @Bindable var preferences: Preferences
    let hotKeyCenter: HotKeyCenter

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("Dictation") {
                LabeledContent("Hotkey") {
                    HotKeyRecorderView(combo: $preferences.hotKey, hotKeyCenter: hotKeyCenter)
                }
                Text("Press once to start listening. Press again to finish. Press ⎋ while listening to cancel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Paste each sentence as soon as you pause", isOn: $preferences.turnMode)
                if preferences.turnMode {
                    LabeledContent("Pause that ends a sentence") {
                        HStack {
                            Slider(value: $preferences.pauseSeconds, in: Preferences.pauseSecondsRange, step: 0.1)
                                .frame(width: 160)
                            Text(String(format: "%.1f s", preferences.pauseSeconds))
                                .font(.callout.monospacedDigit())
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                } else {
                    Text("Off: everything is transcribed once, after you press the hotkey again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("Language code", text: $preferences.language, prompt: Text("en, nl, de, or auto"))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                Text("Only used by multilingual models. English-only models ignore it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Audio") {
                Toggle("Noise suppression (Apple voice processing)", isOn: $preferences.noiseSuppression)
                Toggle("Play start and stop sounds", isOn: $preferences.playSounds)
            }

            Section("Output") {
                Toggle("Add a space after each pasted sentence", isOn: $preferences.appendTrailingSpace)
                Toggle("Use the GPU (Metal) for the models", isOn: $preferences.useGPU)
            }

            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        applyLaunchAtLogin(enabled)
                    }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled: enabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}

struct ModelSettingsView: View {
    @Bindable var preferences: Preferences
    var modelStore: ModelStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Models are stored in \(modelStore.directory.path)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.horizontal)
                .padding(.top, 8)
            List {
                Section {
                    AssetRow(
                        title: VADModel.silero.fileName,
                        detail: "Silero voice activity model, 1 MB. Finds the pauses between your sentences.",
                        isDownloaded: modelStore.isDownloaded(VADModel.silero),
                        progress: modelStore.progress(for: VADModel.silero),
                        errorText: modelStore.error(for: VADModel.silero),
                        onDownload: { modelStore.download(VADModel.silero) },
                        onCancel: { modelStore.cancelDownload(VADModel.silero) }
                    )
                } header: {
                    Text("Voice activity")
                }
                ForEach(WhisperModelFamily.allCases) { family in
                    Section {
                        ForEach(WhisperModel.models(in: family)) { model in
                            ModelRow(
                                model: model,
                                isSelected: preferences.selectedModelName == model.name,
                                isDownloaded: modelStore.isDownloaded(model),
                                progress: modelStore.progress(for: model),
                                errorText: modelStore.error(for: model),
                                onSelect: { preferences.selectedModelName = model.name },
                                onDownload: { modelStore.download(model) },
                                onCancel: { modelStore.cancelDownload(model) },
                                onDelete: { try? modelStore.delete(model) }
                            )
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(family.title)
                            Text(family.summary).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct ModelRow: View {
    let model: WhisperModel
    let isSelected: Bool
    let isDownloaded: Bool
    let progress: Double?
    let errorText: String?
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!isDownloaded)
            .help(isDownloaded ? "Use this model" : "Download the model first")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name).font(.body.weight(.medium))
                    Text(model.sizeDescription).font(.caption).foregroundStyle(.secondary)
                    Text(model.languageDescription)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
                Text(model.summary).font(.caption).foregroundStyle(.secondary)
                if let errorText {
                    Text(errorText).font(.caption).foregroundStyle(.red)
                }
            }

            Spacer()

            trailingControl
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var trailingControl: some View {
        if let progress {
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 90)
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 36, alignment: .trailing)
                Button("Cancel", action: onCancel)
                    .controlSize(.small)
            }
        } else if isDownloaded {
            Button("Delete", role: .destructive, action: onDelete)
                .controlSize(.small)
                .disabled(isSelected)
                .help(isSelected ? "Select another model before deleting this one" : "Delete the model file")
        } else {
            Button("Download", action: onDownload)
                .controlSize(.small)
        }
    }
}

struct AssetRow: View {
    let title: String
    let detail: String
    let isDownloaded: Bool
    let progress: Double?
    let errorText: String?
    let onDownload: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                .foregroundStyle(isDownloaded ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                if let errorText {
                    Text(errorText).font(.caption).foregroundStyle(.red)
                }
            }
            Spacer()
            if let progress {
                HStack(spacing: 8) {
                    ProgressView(value: progress).frame(width: 90)
                    Button("Cancel", action: onCancel).controlSize(.small)
                }
            } else if !isDownloaded {
                Button("Download", action: onDownload).controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CorrectionSettingsView: View {
    @Bindable var preferences: Preferences
    var modelStore: ModelStore

    var body: some View {
        Form {
            Section {
                Toggle("Correct each sentence with a local language model", isOn: $preferences.correctionEnabled)
                Text("The model fixes punctuation, capitalization, filler words, and words the recognizer misheard. It runs on this Mac. A sanity check keeps the raw transcript whenever the model changes too many words.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Correction")
            }

            Section("Model") {
                ForEach(CorrectionModel.catalog) { model in
                    CorrectionModelRow(
                        model: model,
                        isSelected: preferences.correctionModelName == model.name,
                        isDownloaded: modelStore.isDownloaded(model),
                        progress: modelStore.progress(for: model),
                        errorText: modelStore.error(for: model),
                        onSelect: { preferences.correctionModelName = model.name },
                        onDownload: { modelStore.download(model) },
                        onCancel: { modelStore.cancelDownload(model) },
                        onDelete: { try? modelStore.delete(model) }
                    )
                }
            }

            Section {
                TextEditor(text: $preferences.vocabulary)
                    .font(.body)
                    .frame(minHeight: 70)
                Text("Names, products, and jargon the recognizer gets wrong. One per line or comma separated. Whisper and the correction model both see this list, which nudges them toward these spellings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Vocabulary")
            }

            Section {
                TextEditor(text: $preferences.replacements)
                    .font(.body.monospaced())
                    .frame(minHeight: 70)
                Text("Exact fixes applied to every transcript, one per line, in the form wrong = right. Use this for a word the recognizer always mishears, for example Vesper = whisper. Whole words only, any capitalization.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Always replace")
            }
        }
        .formStyle(.grouped)
    }
}

private struct CorrectionModelRow: View {
    let model: CorrectionModel
    let isSelected: Bool
    let isDownloaded: Bool
    let progress: Double?
    let errorText: String?
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!isDownloaded)
            .help(isDownloaded ? "Use this model" : "Download the model first")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name).font(.body.weight(.medium))
                    Text(model.sizeDescription).font(.caption).foregroundStyle(.secondary)
                }
                Text(model.summary).font(.caption).foregroundStyle(.secondary)
                if let errorText {
                    Text(errorText).font(.caption).foregroundStyle(.red)
                }
            }

            Spacer()

            if let progress {
                HStack(spacing: 8) {
                    ProgressView(value: progress).frame(width: 90)
                    Text("\(Int(progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 36, alignment: .trailing)
                    Button("Cancel", action: onCancel).controlSize(.small)
                }
            } else if isDownloaded {
                Button("Delete", role: .destructive, action: onDelete)
                    .controlSize(.small)
                    .disabled(isSelected)
            } else {
                Button("Download", action: onDownload).controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PermissionsSettingsView: View {
    static let pollInterval: TimeInterval = 1

    @State private var microphoneAuthorized = Permissions.isMicrophoneAuthorized
    @State private var accessibilityTrusted = Permissions.isAccessibilityTrusted

    private let timer = Timer.publish(every: PermissionsSettingsView.pollInterval, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    title: "Microphone",
                    detail: "Needed to hear you while the hotkey is active.",
                    granted: microphoneAuthorized,
                    requestTitle: "Request Access",
                    onRequest: { Task { _ = await Permissions.requestMicrophone(); refresh() } },
                    onOpenSettings: Permissions.openMicrophoneSettings
                )
                PermissionRow(
                    title: "Accessibility",
                    detail: "Needed to find the focused text field and press ⌘V for you. Without it, transcripts go to the clipboard.",
                    granted: accessibilityTrusted,
                    requestTitle: "Request Access",
                    onRequest: { Permissions.promptForAccessibility() },
                    onOpenSettings: Permissions.openAccessibilitySettings
                )
            } header: {
                Text("Permissions")
            } footer: {
                Text("macOS remembers these per app build. If you rebuild with a different signing identity you may need to grant them again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onReceive(timer) { _ in refresh() }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        microphoneAuthorized = Permissions.isMicrophoneAuthorized
        accessibilityTrusted = Permissions.isAccessibilityTrusted
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let requestTitle: String
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? Color.green : Color.red)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                VStack(alignment: .trailing, spacing: 6) {
                    Button(requestTitle, action: onRequest).controlSize(.small)
                    Button("Open System Settings", action: onOpenSettings).controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
