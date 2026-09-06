import Foundation
import whisper

final class WhisperEngine {
    enum EngineError: LocalizedError {
        case modelLoadFailed(String)
        case transcriptionFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .modelLoadFailed(let path): return "Could not load the model at \(path)."
            case .transcriptionFailed(let code): return "whisper_full returned \(code)."
            }
        }
    }

    static let sampleRate = 16_000
    static let maximumThreads = 8
    static let minimumAudioSeconds = 1.1
    static let noSpeechThreshold: Float = 0.6
    static let englishLanguageCode = "en"

    let modelName: String

    private let context: OpaquePointer
    private let queue = DispatchQueue(label: "com.amankumar.saytype.whisper", qos: .userInitiated)

    init(modelURL: URL, modelName: String, useGPU: Bool) throws {
        Self.installLogHandler()
        var parameters = whisper_context_default_params()
        parameters.use_gpu = useGPU
        parameters.flash_attn = useGPU
        guard let context = whisper_init_from_file_with_params(modelURL.path, parameters) else {
            throw EngineError.modelLoadFailed(modelURL.path)
        }
        self.context = context
        self.modelName = modelName
        Log.whisper.info("Loaded \(modelName) (gpu: \(useGPU))")
    }

    deinit {
        whisper_free(context)
    }

    var isMultilingual: Bool {
        whisper_is_multilingual(context) != 0
    }

    func transcribe(_ samples: [Float], language: String, initialPrompt: String? = nil) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try self.runTranscription(samples, language: language, initialPrompt: initialPrompt))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runTranscription(_ input: [Float], language: String, initialPrompt: String?) throws -> String {
        let samples = Self.paddedToMinimumLength(input)
        var parameters = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        parameters.n_threads = Int32(min(Self.maximumThreads, ProcessInfo.processInfo.activeProcessorCount))
        parameters.no_timestamps = true
        parameters.print_progress = false
        parameters.print_realtime = false
        parameters.print_timestamps = false
        parameters.print_special = false
        parameters.suppress_blank = true
        parameters.suppress_nst = true
        parameters.translate = false
        parameters.detect_language = false
        parameters.no_speech_thold = Self.noSpeechThreshold

        let effectiveLanguage = isMultilingual ? language : Self.englishLanguageCode
        let prompt = initialPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let started = Date()
        let status = effectiveLanguage.withCString { languagePointer -> Int32 in
            parameters.language = languagePointer
            return prompt.withCString { promptPointer -> Int32 in
                parameters.initial_prompt = prompt.isEmpty ? nil : promptPointer
                return samples.withUnsafeBufferPointer { buffer in
                    whisper_full(context, parameters, buffer.baseAddress, Int32(buffer.count))
                }
            }
        }
        guard status == 0 else { throw EngineError.transcriptionFailed(status) }

        let segmentCount = whisper_full_n_segments(context)
        var text = ""
        for index in 0..<segmentCount {
            guard let segment = whisper_full_get_segment_text(context, index) else { continue }
            text += String(cString: segment)
        }
        let elapsed = Date().timeIntervalSince(started)
        Log.whisper.info("Transcribed \(samples.count) samples in \(elapsed, format: .fixed(precision: 2)) s")
        return text
    }

    private static func paddedToMinimumLength(_ samples: [Float]) -> [Float] {
        let minimumCount = Int(minimumAudioSeconds * Double(sampleRate))
        guard samples.count < minimumCount else { return samples }
        return samples + [Float](repeating: 0, count: minimumCount - samples.count)
    }

    private static let logHandlerInstallation: Void = {
        whisper_log_set({ level, message, _ in
            guard let message else { return }
            let text = String(cString: message).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            if level == GGML_LOG_LEVEL_ERROR {
                Log.whisper.error("\(text)")
            } else {
                Log.whisper.debug("\(text)")
            }
        }, nil)
    }()

    private static func installLogHandler() {
        _ = logHandlerInstallation
    }
}
