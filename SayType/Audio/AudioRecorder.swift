import AVFoundation
import Foundation

final class AudioRecorder {
    static let targetSampleRate: Double = 16_000
    static let tapBufferSize: AVAudioFrameCount = 2_048
    static let maximumDuration: TimeInterval = 5 * 60

    enum RecorderError: LocalizedError {
        case noInputDevice
        case converterUnavailable

        var errorDescription: String? {
            switch self {
            case .noInputDevice: return "No microphone is available."
            case .converterUnavailable: return "The microphone format cannot be converted."
            }
        }
    }

    private let engine = AVAudioEngine()
    private let sampleLock = NSLock()
    private var converter: AVAudioConverter?
    private var samples: [Float] = []
    private var didReportMaximumDuration = false

    private(set) var isRecording = false

    var onLevel: ((Float) -> Void)?
    var onChunk: (([Float]) -> Void)?
    var onMaximumDurationReached: (() -> Void)?

    func start(voiceProcessing: Bool) throws {
        guard !isRecording else { return }

        let inputNode = engine.inputNode
        applyVoiceProcessing(voiceProcessing, to: inputNode)

        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw RecorderError.noInputDevice
        }
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw RecorderError.converterUnavailable
        }

        self.converter = converter
        didReportMaximumDuration = false
        sampleLock.lock()
        samples.removeAll(keepingCapacity: true)
        sampleLock.unlock()

        inputNode.installTap(onBus: 0, bufferSize: Self.tapBufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.consume(buffer)
        }
        engine.prepare()
        try engine.start()
        isRecording = true
        Log.audio.info("Recording started at \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) channels, voice processing \(inputNode.isVoiceProcessingEnabled)")
    }

    func stop() -> [Float] {
        guard isRecording else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        converter = nil

        sampleLock.lock()
        defer { sampleLock.unlock() }
        let captured = samples
        samples = []
        Log.audio.info("Recording stopped with \(captured.count) samples")
        return captured
    }

    private func applyVoiceProcessing(_ enabled: Bool, to inputNode: AVAudioInputNode) {
        guard inputNode.isVoiceProcessingEnabled != enabled else { return }
        do {
            try inputNode.setVoiceProcessingEnabled(enabled)
            if enabled {
                inputNode.voiceProcessingOtherAudioDuckingConfiguration = AVAudioVoiceProcessingOtherAudioDuckingConfiguration(
                    enableAdvancedDucking: false,
                    duckingLevel: .min
                )
            }
        } catch {
            Log.audio.error("Voice processing could not be set to \(enabled): \(error.localizedDescription)")
        }
    }

    private func consume(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = Self.targetSampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let converted = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else { return }

        var didSupplyInput = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, outStatus in
            if didSupplyInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            didSupplyInput = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, let channelData = converted.floatChannelData else {
            if let conversionError {
                Log.audio.error("Sample rate conversion failed: \(conversionError.localizedDescription)")
            }
            return
        }

        let frameCount = Int(converted.frameLength)
        let chunk = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        append(chunk)
        onChunk?(chunk)
        publishLevel(for: chunk)
    }

    private func append(_ chunk: [Float]) {
        sampleLock.lock()
        samples.append(contentsOf: chunk)
        let totalSamples = samples.count
        sampleLock.unlock()

        let duration = Double(totalSamples) / Self.targetSampleRate
        guard duration >= Self.maximumDuration, !didReportMaximumDuration else { return }
        didReportMaximumDuration = true
        DispatchQueue.main.async { [weak self] in
            self?.onMaximumDurationReached?()
        }
    }

    private func publishLevel(for chunk: [Float]) {
        let level = AudioAnalysis.rootMeanSquare(chunk)
        DispatchQueue.main.async { [weak self] in
            self?.onLevel?(level)
        }
    }
}
