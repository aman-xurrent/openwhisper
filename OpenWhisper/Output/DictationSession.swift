import Foundation

struct DictationSessionConfiguration {
    var language: String
    var vocabulary: [String]
    var correctionEnabled: Bool
    var appendTrailingSpace: Bool
    var replacements: [ReplacementRule]
}

struct DictationProgress: Equatable {
    var deliveredTurns = 0
    var pendingTurns = 0
    var lastText: String?
}

@MainActor
final class DictationSession {
    enum Outcome: Equatable {
        case nothingHeard
        case delivered(turns: Int, pasted: Bool)
        case cancelled
    }

    static let correctionTimeout: TimeInterval = 8
    static let promptContextCharacters = 400
    static let correctionContextTurns = 2

    var onProgress: ((DictationProgress) -> Void)?

    private let configuration: DictationSessionConfiguration
    private let transcriber: () async throws -> WhisperEngine
    private let corrector: (() async throws -> CorrectionEngine)?
    private let inserter: TextInserter

    private var processingTask: Task<Void, Never>?
    private var progress = DictationProgress()
    private var deliveredTexts: [String] = []
    private var clipboardTexts: [String] = []
    private var usedClipboard = false
    private var isCancelled = false
    private var failedTurns = 0
    private(set) var enqueuedTurns = 0

    init(
        configuration: DictationSessionConfiguration,
        transcriber: @escaping () async throws -> WhisperEngine,
        corrector: (() async throws -> CorrectionEngine)?,
        inserter: TextInserter
    ) {
        self.configuration = configuration
        self.transcriber = transcriber
        self.corrector = corrector
        self.inserter = inserter
    }

    func enqueue(turn samples: [Float]) {
        guard !isCancelled else { return }
        enqueuedTurns += 1
        progress.pendingTurns += 1
        onProgress?(progress)
        let previous = processingTask
        processingTask = Task { [weak self] in
            await previous?.value
            guard let self, !self.isCancelled else { return }
            await self.process(samples)
        }
    }

    func finish() async -> Outcome {
        await processingTask?.value
        if isCancelled { return .cancelled }
        guard progress.deliveredTurns > 0 else { return .nothingHeard }
        return .delivered(turns: progress.deliveredTurns, pasted: !usedClipboard)
    }

    func cancel() {
        isCancelled = true
        processingTask?.cancel()
    }

    private func process(_ samples: [Float]) async {
        defer {
            progress.pendingTurns = max(0, progress.pendingTurns - 1)
            onProgress?(progress)
        }
        guard AudioAnalysis.containsSpeech(samples) else { return }

        do {
            let raw = try await transcribe(samples)
            guard !raw.isEmpty else { return }
            let corrected = await self.corrected(raw)
            let text = TranscriptReplacer.apply(rules: configuration.replacements, to: corrected)
            guard !isCancelled else { return }
            deliver(text)
        } catch {
            failedTurns += 1
            Log.session.error("Turn failed: \(error.localizedDescription)")
        }
    }

    private func transcribe(_ samples: [Float]) async throws -> String {
        let engine = try await transcriber()
        let raw = try await engine.transcribe(samples, language: configuration.language, initialPrompt: whisperPrompt())
        return TranscriptCleaner.clean(raw)
    }

    private func whisperPrompt() -> String? {
        var parts: [String] = []
        if !configuration.vocabulary.isEmpty {
            parts.append(configuration.vocabulary.joined(separator: ", ") + ".")
        }
        if let last = deliveredTexts.last {
            parts.append(String(last.suffix(Self.promptContextCharacters)))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func corrected(_ raw: String) async -> String {
        guard configuration.correctionEnabled, let corrector else { return raw }
        let request = CorrectionRequest(
            transcript: raw,
            previousText: deliveredTexts.suffix(Self.correctionContextTurns).joined(separator: " "),
            vocabulary: configuration.vocabulary
        )
        do {
            let engine = try await corrector()
            let output = try await withTimeout(seconds: Self.correctionTimeout) {
                try await engine.correct(request)
            }
            guard let accepted = CorrectionValidator.accept(raw: raw, corrected: output) else {
                Log.session.info("Correction rejected, keeping raw text. Raw: \(raw) Output: \(output)")
                return raw
            }
            return accepted
        } catch {
            Log.session.error("Correction failed, keeping raw text: \(error.localizedDescription)")
            return raw
        }
    }

    private func deliver(_ text: String) {
        let separator = TranscriptJoiner.separator(afterPrevious: deliveredTexts.last)
        var outgoing = separator + text
        if configuration.appendTrailingSpace {
            outgoing += " "
        }

        if usedClipboard {
            clipboardTexts.append(outgoing)
            inserter.copy(clipboardTexts.joined())
        } else {
            switch inserter.deliver(outgoing) {
            case .pasted:
                break
            case .copied:
                usedClipboard = true
                clipboardTexts = [outgoing]
            }
        }

        deliveredTexts.append(outgoing)
        progress.deliveredTurns += 1
        progress.lastText = text
        onProgress?(progress)
    }
}

enum TimeoutError: LocalizedError {
    case timedOut(TimeInterval)

    var errorDescription: String? {
        switch self {
        case .timedOut(let seconds): return "Timed out after \(Int(seconds)) seconds."
        }
    }
}

func withTimeout<Value>(seconds: TimeInterval, operation: @escaping () async throws -> Value) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError.timedOut(seconds)
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
