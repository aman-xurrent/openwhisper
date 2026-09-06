import AppKit
import Foundation

@MainActor
final class AppCoordinator {
    enum Phase {
        case idle
        case recording
        case transcribing
    }

    static let messageDuration: TimeInterval = 1.8
    static let minimumRecordingSeconds = 0.3
    static let startSoundName = NSSound.Name("Tink")
    static let stopSoundName = NSSound.Name("Pop")

    let preferences: Preferences
    let modelStore: ModelStore

    private let recorder = AudioRecorder()
    private let inserter = TextInserter()
    private let hudModel = HUDModel()
    private let statusItem = StatusItemController()
    private let vadQueue = DispatchQueue(label: "com.amankumar.saytype.vad", qos: .userInteractive)
    private lazy var hudPanel = HUDPanel(model: hudModel)
    private lazy var settingsWindow = SettingsWindowController(
        preferences: preferences,
        modelStore: modelStore,
        hotKeyCenter: HotKeyCenter.shared
    )

    private lazy var whisperLoader = EngineLoader<WhisperEngine>(make: makeWhisperEngine())
    private lazy var correctionLoader = EngineLoader<CorrectionEngine>(make: makeCorrectionEngine())
    private lazy var vadLoader = EngineLoader<VoiceActivityDetector>(make: makeVoiceActivityDetector())

    private let liveTurns = LiveTurnDetection()
    private var session: DictationSession?
    private var dictationHotKeyIdentifier: UInt32?
    private var cancelHotKeyIdentifier: UInt32?
    private var messageDismissal: DispatchWorkItem?
    private var preferencesObserver: NSObjectProtocol?
    private var modelStoreObserver: NSObjectProtocol?

    private(set) var phase: Phase = .idle {
        didSet { updateStatusItem() }
    }

    init(preferences: Preferences, modelStore: ModelStore) {
        self.preferences = preferences
        self.modelStore = modelStore
    }

    func start() {
        wireStatusItem()
        wireRecorder()
        registerDictationHotKey()
        observePreferences()
        observeModelStore()
        updateStatusItem()
        preloadEngines()
        Task { await runFirstLaunchChecks() }
    }

    func toggleDictation() {
        switch phase {
        case .idle: Task { await beginRecording() }
        case .recording: Task { await finishRecording() }
        case .transcribing: break
        }
    }

    func cancelDictation() {
        guard phase == .recording else { return }
        _ = recorder.stop()
        let liveTurns = self.liveTurns
        vadQueue.sync { liveTurns.clear() }
        unregisterCancelHotKey()
        session?.cancel()
        session = nil
        phase = .idle
        showMessage("Cancelled", kind: .info)
    }

    func openSettings(tab: SettingsTab? = nil) {
        settingsWindow.show(tab: tab)
    }

    private func wireStatusItem() {
        statusItem.onToggle = { [weak self] in self?.toggleDictation() }
        statusItem.onOpenSettings = { [weak self] in self?.openSettings() }
        statusItem.onQuit = { NSApp.terminate(nil) }
    }

    private func wireRecorder() {
        recorder.onLevel = { [weak self] level in self?.hudModel.push(level: level) }
        recorder.onMaximumDurationReached = { [weak self] in
            guard let self, phase == .recording else { return }
            Task { await self.finishRecording() }
        }
        recorder.onChunk = { [weak self] chunk in
            self?.vadQueue.async { self?.detectTurns(in: chunk) }
        }
    }

    private func observePreferences() {
        preferencesObserver = NotificationCenter.default.addObserver(
            forName: Preferences.didChange,
            object: preferences,
            queue: .main
        ) { [weak self] notification in
            guard let key = notification.userInfo?[Preferences.changedKeyUserInfoKey] as? Preferences.Key else { return }
            Task { @MainActor in self?.preferencesDidChange(key) }
        }
    }

    private func observeModelStore() {
        modelStoreObserver = NotificationCenter.default.addObserver(
            forName: ModelStore.didChange,
            object: modelStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.preloadEngines()
                self?.updateStatusItem()
            }
        }
    }

    private func preferencesDidChange(_ key: Preferences.Key) {
        switch key {
        case .hotKey:
            registerDictationHotKey()
            updateStatusItem()
        case .selectedModelName, .useGPU:
            whisperLoader.reset(make: makeWhisperEngine())
            correctionLoader.reset(make: makeCorrectionEngine())
            preloadEngines()
            updateStatusItem()
        case .correctionModelName:
            correctionLoader.reset(make: makeCorrectionEngine())
            preloadEngines()
        case .correctionEnabled:
            if preferences.correctionEnabled {
                preloadEngines()
            } else {
                correctionLoader.unload()
            }
        case .language, .playSounds, .appendTrailingSpace, .turnMode, .pauseSeconds, .noiseSuppression, .vocabulary, .replacements:
            break
        }
    }

    private func runFirstLaunchChecks() async {
        if Permissions.microphoneStatus == .notDetermined {
            _ = await Permissions.requestMicrophone()
        }
        if !modelStore.isDownloaded(VADModel.silero) {
            modelStore.download(VADModel.silero)
        }
        let needsAccessibility = !Permissions.isAccessibilityTrusted
        let needsWhisper = !modelStore.isDownloaded(preferences.selectedModel)
        let needsCorrection = preferences.correctionEnabled && !modelStore.isDownloaded(preferences.correctionModel)
        if needsWhisper {
            modelStore.download(preferences.selectedModel)
        }
        if needsCorrection {
            modelStore.download(preferences.correctionModel)
        }
        if needsWhisper || needsCorrection {
            openSettings(tab: needsWhisper ? .model : .correction)
        } else if needsAccessibility {
            openSettings(tab: .permissions)
        }
        if needsAccessibility {
            Permissions.promptForAccessibility()
        }
    }

    private func makeWhisperEngine() -> () throws -> WhisperEngine {
        let model = preferences.selectedModel
        let url = modelStore.fileURL(for: model)
        let useGPU = preferences.useGPU
        return { try WhisperEngine(modelURL: url, modelName: model.name, useGPU: useGPU) }
    }

    private func makeCorrectionEngine() -> () throws -> CorrectionEngine {
        let model = preferences.correctionModel
        let url = modelStore.fileURL(for: model)
        let useGPU = preferences.useGPU
        return { try CorrectionEngine(modelURL: url, modelName: model.name, useGPU: useGPU) }
    }

    private func makeVoiceActivityDetector() -> () throws -> VoiceActivityDetector {
        let url = modelStore.fileURL(for: VADModel.silero)
        return { try VoiceActivityDetector(modelURL: url) }
    }

    private func preloadEngines() {
        if modelStore.isDownloaded(preferences.selectedModel), whisperLoader.loaded == nil {
            whisperLoader.preload()
        }
        if preferences.correctionEnabled, modelStore.isDownloaded(preferences.correctionModel), correctionLoader.loaded == nil {
            correctionLoader.preload()
        }
        if modelStore.isDownloaded(VADModel.silero), vadLoader.loaded == nil {
            vadLoader.preload()
        }
    }

    private func registerDictationHotKey() {
        if let identifier = dictationHotKeyIdentifier {
            HotKeyCenter.shared.unregister(identifier)
        }
        dictationHotKeyIdentifier = HotKeyCenter.shared.register(preferences.hotKey) { [weak self] in
            self?.toggleDictation()
        }
        hudModel.hotKeyDescription = preferences.hotKey.displayString
        if dictationHotKeyIdentifier == nil {
            showMessage("Could not register \(preferences.hotKey.displayString)", kind: .warning)
        }
    }

    private func registerCancelHotKey() {
        unregisterCancelHotKey()
        cancelHotKeyIdentifier = HotKeyCenter.shared.register(.escape) { [weak self] in
            self?.cancelDictation()
        }
    }

    private func unregisterCancelHotKey() {
        guard let identifier = cancelHotKeyIdentifier else { return }
        HotKeyCenter.shared.unregister(identifier)
        cancelHotKeyIdentifier = nil
    }

    private func beginRecording() async {
        guard phase == .idle else { return }
        guard Permissions.isMicrophoneAuthorized else {
            showMessage("Microphone access is needed", kind: .warning)
            openSettings(tab: .permissions)
            return
        }
        guard modelStore.isDownloaded(preferences.selectedModel) else {
            showMessage("Download the \(preferences.selectedModel.name) model first", kind: .warning)
            openSettings(tab: .model)
            return
        }

        if preferences.turnMode {
            guard await prepareTurnDetection() else { return }
        }

        do {
            try recorder.start(voiceProcessing: preferences.noiseSuppression)
        } catch {
            Log.app.error("Recorder failed to start: \(error.localizedDescription)")
            showMessage(error.localizedDescription, kind: .warning)
            return
        }

        session = makeSession()
        messageDismissal?.cancel()
        hudModel.resetLevels()
        hudModel.detail = ""
        hudModel.phase = .recording
        hudPanel.present()
        phase = .recording
        registerCancelHotKey()
        playSound(Self.startSoundName)
        preloadEngines()
    }

    private func prepareTurnDetection() async -> Bool {
        guard modelStore.isDownloaded(VADModel.silero) else {
            modelStore.download(VADModel.silero)
            showMessage("Downloading the voice activity model, try again in a moment", kind: .warning)
            return false
        }
        do {
            let detector = try await vadLoader.value()
            let configuration = TurnDetectorConfiguration(pauseSeconds: preferences.pauseSeconds)
            let turnDetector = TurnDetector(configuration: configuration)
            let liveTurns = self.liveTurns
            vadQueue.sync {
                liveTurns.configure(detector: detector, turnDetector: turnDetector)
            }
            return true
        } catch {
            Log.app.error("Voice activity detector failed to load: \(error.localizedDescription)")
            showMessage("Voice activity model failed to load", kind: .warning)
            return false
        }
    }

    private func makeSession() -> DictationSession {
        let configuration = DictationSessionConfiguration(
            language: preferences.language,
            vocabulary: preferences.vocabularyTerms,
            correctionEnabled: preferences.correctionEnabled && modelStore.isDownloaded(preferences.correctionModel),
            appendTrailingSpace: preferences.appendTrailingSpace,
            replacements: preferences.replacementRules
        )
        let whisperLoader = self.whisperLoader
        let correctionLoader = self.correctionLoader
        let session = DictationSession(
            configuration: configuration,
            transcriber: { try await whisperLoader.value() },
            corrector: configuration.correctionEnabled ? { try await correctionLoader.value() } : nil,
            inserter: inserter
        )
        session.onProgress = { [weak self] progress in
            self?.hudModel.detail = Self.detailText(for: progress)
        }
        return session
    }

    private nonisolated func detectTurns(in chunk: [Float]) {
        for event in liveTurns.process(chunk) {
            DispatchQueue.main.async { [weak self] in self?.handle(event) }
        }
    }

    private func handle(_ event: TurnDetector.Event) {
        guard phase == .recording else { return }
        switch event {
        case .speechStarted:
            break
        case .turnEnded(let samples):
            session?.enqueue(turn: samples)
        }
    }

    private func finishRecording() async {
        guard phase == .recording, let session else { return }
        let allSamples = recorder.stop()
        unregisterCancelHotKey()
        playSound(Self.stopSoundName)
        phase = .transcribing
        hudModel.phase = .transcribing
        hudPanel.present()

        let peak = AudioAnalysis.peakRootMeanSquare(allSamples)
        let liveTurns = self.liveTurns
        let peakProbability = liveTurns.peakProbability
        let duration = Double(allSamples.count) / AudioRecorder.targetSampleRate
        Log.app.notice("Recording finished: \(String(format: "%.1f", duration)) s, \(allSamples.count) samples, peak RMS \(String(format: "%.4f", peak)), peak VAD \(String(format: "%.2f", peakProbability)), voice processing \(self.preferences.noiseSuppression)")

        if preferences.turnMode {
            if let remainder = vadQueue.sync(execute: { liveTurns.flush() }) {
                session.enqueue(turn: remainder)
            }
            if session.enqueuedTurns == 0, AudioAnalysis.containsSpeech(allSamples) {
                Log.app.notice("Turn detector produced nothing, transcribing the whole recording")
                session.enqueue(turn: allSamples)
            }
        } else if duration >= Self.minimumRecordingSeconds {
            session.enqueue(turn: allSamples)
        }

        let outcome = await session.finish()
        self.session = nil
        phase = .idle
        report(outcome, peak: peak)
    }

    private func report(_ outcome: DictationSession.Outcome, peak: Float) {
        switch outcome {
        case .nothingHeard:
            if peak < AudioAnalysis.silenceFloor {
                showMessage("No microphone signal. Check the input device and mic access.", kind: .warning)
            } else {
                showMessage("No speech detected", kind: .warning)
            }
        case .cancelled:
            showMessage("Cancelled", kind: .info)
        case .delivered(let turns, let pasted):
            let noun = turns == 1 ? "sentence" : "sentences"
            showMessage(pasted ? "Pasted \(turns) \(noun)" : "Copied \(turns) \(noun) to clipboard", kind: .success)
        }
    }

    private static func detailText(for progress: DictationProgress) -> String {
        var parts: [String] = []
        if progress.deliveredTurns > 0 {
            parts.append("\(progress.deliveredTurns) pasted")
        }
        if progress.pendingTurns > 0 {
            parts.append("\(progress.pendingTurns) in progress")
        }
        return parts.joined(separator: " · ")
    }

    private func showMessage(_ text: String, kind: HUDModel.MessageKind) {
        messageDismissal?.cancel()
        hudModel.phase = .message(text, kind)
        hudPanel.present()
        let dismissal = DispatchWorkItem { [weak self] in
            guard let self, case .message = hudModel.phase else { return }
            hudPanel.dismiss()
            hudModel.phase = .hidden
        }
        messageDismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.messageDuration, execute: dismissal)
    }

    private func playSound(_ name: NSSound.Name) {
        guard preferences.playSounds else { return }
        NSSound(named: name)?.play()
    }

    private func updateStatusItem() {
        let modelName = modelStore.isDownloaded(preferences.selectedModel) ? preferences.selectedModel.name : nil
        statusItem.update(phase: phase, hotKey: preferences.hotKey, modelName: modelName)
    }
}
