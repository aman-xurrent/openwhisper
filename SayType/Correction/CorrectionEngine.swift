import Foundation

final class CorrectionEngine {
    enum EngineError: LocalizedError {
        case modelLoadFailed(String)
        case generationFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .modelLoadFailed(let path): return "Could not load the correction model at \(path)."
            case .generationFailed(let code): return "The correction model failed with code \(code)."
            }
        }
    }

    static let contextTokens: UInt32 = 2_048
    static let maximumOutputTokens: Int32 = 256
    static let outputBufferBytes = 8_192
    static let maximumThreads = 8

    let modelName: String

    private let handle: OpaquePointer
    private let queue = DispatchQueue(label: "com.amankumar.saytype.correction", qos: .userInitiated)

    init(modelURL: URL, modelName: String, useGPU: Bool) throws {
        Self.installLogHandler()
        let threads = Int32(min(Self.maximumThreads, ProcessInfo.processInfo.activeProcessorCount))
        guard let handle = saytype_llm_open(modelURL.path, useGPU, Self.contextTokens, threads) else {
            throw EngineError.modelLoadFailed(modelURL.path)
        }
        self.handle = handle
        self.modelName = modelName
        Log.correction.info("Loaded \(modelName) (gpu: \(useGPU))")
    }

    deinit {
        saytype_llm_close(handle)
    }

    func correct(_ request: CorrectionRequest) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try self.runCorrection(request))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runCorrection(_ request: CorrectionRequest) throws -> String {
        let started = Date()
        var output = [CChar](repeating: 0, count: Self.outputBufferBytes)
        let written = saytype_llm_complete(
            handle,
            CorrectionPrompt.systemInstructions,
            CorrectionPrompt.userMessage(for: request),
            Self.maximumOutputTokens,
            &output,
            Int32(output.count)
        )
        guard written >= 0 else { throw EngineError.generationFailed(written) }
        let text = String(decoding: output[0..<Int(written)].map { UInt8(bitPattern: $0) }, as: UTF8.self)
        let elapsed = Date().timeIntervalSince(started)
        Log.correction.info("Corrected \(request.transcript.count) characters in \(elapsed, format: .fixed(precision: 2)) s")
        return text
    }

    private static let logHandlerInstallation: Void = {
        saytype_llm_set_log_callback({ level, message, _ in
            guard let message else { return }
            let text = String(cString: message).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            if level == SAYTYPE_LLM_LOG_LEVEL_ERROR {
                Log.correction.error("\(text)")
            } else {
                Log.correction.debug("\(text)")
            }
        }, nil)
    }()

    private static func installLogHandler() {
        _ = logHandlerInstallation
    }
}
