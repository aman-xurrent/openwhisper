import Foundation
import whisper

struct VADModel: DownloadableAsset, Hashable {
    let fileName: String
    let downloadURL: URL

    static let silero = VADModel(
        fileName: "ggml-silero-v5.1.2.bin",
        downloadURL: URL(string: "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin")!
    )
}

struct VoiceActivityResult {
    let consumedSamples: [Float]
    let probabilities: [Float]
}

final class VoiceActivityDetector {
    enum DetectorError: LocalizedError {
        case modelLoadFailed(String)

        var errorDescription: String? {
            switch self {
            case .modelLoadFailed(let path): return "Could not load the voice activity model at \(path)."
            }
        }
    }

    static let windowSize = 512

    private let context: OpaquePointer
    private var pending: [Float] = []

    init(modelURL: URL) throws {
        var parameters = whisper_vad_default_context_params()
        parameters.n_threads = 1
        parameters.use_gpu = false
        guard let context = whisper_vad_init_from_file_with_params(modelURL.path, parameters) else {
            throw DetectorError.modelLoadFailed(modelURL.path)
        }
        self.context = context
    }

    deinit {
        whisper_vad_free(context)
    }

    func process(_ samples: [Float]) -> VoiceActivityResult {
        pending.append(contentsOf: samples)
        let windowCount = pending.count / Self.windowSize
        guard windowCount > 0 else {
            return VoiceActivityResult(consumedSamples: [], probabilities: [])
        }
        let consumedCount = windowCount * Self.windowSize
        let consumed = Array(pending[0..<consumedCount])
        pending.removeFirst(consumedCount)

        let succeeded = consumed.withUnsafeBufferPointer { buffer in
            whisper_vad_detect_speech_no_reset(context, buffer.baseAddress, Int32(buffer.count))
        }
        guard succeeded, let probabilities = whisper_vad_probs(context) else {
            return VoiceActivityResult(consumedSamples: consumed, probabilities: Array(repeating: 0, count: windowCount))
        }
        let count = Int(whisper_vad_n_probs(context))
        return VoiceActivityResult(
            consumedSamples: consumed,
            probabilities: Array(UnsafeBufferPointer(start: probabilities, count: count))
        )
    }

    func reset() {
        pending.removeAll()
        whisper_vad_reset_state(context)
    }
}
