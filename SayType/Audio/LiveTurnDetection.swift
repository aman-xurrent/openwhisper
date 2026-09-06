import Foundation

final class LiveTurnDetection: @unchecked Sendable {
    private var detector: VoiceActivityDetector?
    private var turnDetector: TurnDetector?
    private(set) var peakProbability: Float = 0

    func configure(detector: VoiceActivityDetector, turnDetector: TurnDetector) {
        detector.reset()
        self.detector = detector
        self.turnDetector = turnDetector
        peakProbability = 0
    }

    func process(_ chunk: [Float]) -> [TurnDetector.Event] {
        guard let detector else { return [] }
        return processProbabilities(detector.process(chunk))
    }

    func processProbabilities(_ result: VoiceActivityResult) -> [TurnDetector.Event] {
        peakProbability = max(peakProbability, result.probabilities.max() ?? 0)
        guard let turnDetector, !result.probabilities.isEmpty else { return [] }
        return turnDetector.process(samples: result.consumedSamples, probabilities: result.probabilities)
    }

    func flush() -> [Float]? {
        defer {
            detector = nil
            turnDetector = nil
        }
        return turnDetector?.flush()
    }

    func clear() {
        detector = nil
        turnDetector = nil
    }
}
