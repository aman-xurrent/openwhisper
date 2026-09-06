import Foundation

struct TurnDetectorConfiguration {
    var sampleRate = 16_000
    var windowSize = VoiceActivityDetector.windowSize
    var speechThreshold: Float = 0.5
    var minimumSpeechSeconds = 0.25
    var pauseSeconds = Preferences.defaultPauseSeconds
    var maximumTurnSeconds = 28.0
    var paddingSeconds = 0.3

    var minimumSpeechSamples: Int { Int(minimumSpeechSeconds * Double(sampleRate)) }
    var pauseSamples: Int { Int(pauseSeconds * Double(sampleRate)) }
    var maximumTurnSamples: Int { Int(maximumTurnSeconds * Double(sampleRate)) }
    var paddingSamples: Int { Int(paddingSeconds * Double(sampleRate)) }
}

final class TurnDetector {
    enum Event: Equatable {
        case speechStarted
        case turnEnded([Float])
    }

    private enum State {
        case silence
        case speech
    }

    let configuration: TurnDetectorConfiguration

    private var state = State.silence
    private var preRoll: [Float] = []
    private var turnSamples: [Float] = []
    private var consecutiveSpeechSamples = 0
    private var trailingSilenceSamples = 0

    init(configuration: TurnDetectorConfiguration = TurnDetectorConfiguration()) {
        self.configuration = configuration
    }

    var isInSpeech: Bool {
        state == .speech
    }

    func process(samples: [Float], probabilities: [Float]) -> [Event] {
        var events: [Event] = []
        for (index, probability) in probabilities.enumerated() {
            let start = index * configuration.windowSize
            let end = min(start + configuration.windowSize, samples.count)
            guard start < end else { break }
            let window = Array(samples[start..<end])
            events.append(contentsOf: consume(window: window, isSpeech: probability >= configuration.speechThreshold))
        }
        return events
    }

    func flush() -> [Float]? {
        defer { reset() }
        guard state == .speech else { return nil }
        let speechLength = turnSamples.count - trailingSilenceSamples
        guard speechLength >= configuration.minimumSpeechSamples else { return nil }
        return trimmedTurn()
    }

    func reset() {
        state = .silence
        preRoll.removeAll()
        turnSamples.removeAll()
        consecutiveSpeechSamples = 0
        trailingSilenceSamples = 0
    }

    private func consume(window: [Float], isSpeech: Bool) -> [Event] {
        switch state {
        case .silence:
            return consumeInSilence(window: window, isSpeech: isSpeech)
        case .speech:
            return consumeInSpeech(window: window, isSpeech: isSpeech)
        }
    }

    private func consumeInSilence(window: [Float], isSpeech: Bool) -> [Event] {
        preRoll.append(contentsOf: window)
        consecutiveSpeechSamples = isSpeech ? consecutiveSpeechSamples + window.count : 0
        let preRollLimit = configuration.paddingSamples + max(consecutiveSpeechSamples, configuration.minimumSpeechSamples)
        if preRoll.count > preRollLimit {
            preRoll.removeFirst(preRoll.count - preRollLimit)
        }
        guard consecutiveSpeechSamples >= configuration.minimumSpeechSamples else { return [] }

        state = .speech
        turnSamples = preRoll
        preRoll.removeAll()
        consecutiveSpeechSamples = 0
        trailingSilenceSamples = 0
        return [.speechStarted]
    }

    private func consumeInSpeech(window: [Float], isSpeech: Bool) -> [Event] {
        turnSamples.append(contentsOf: window)
        trailingSilenceSamples = isSpeech ? 0 : trailingSilenceSamples + window.count

        if trailingSilenceSamples >= configuration.pauseSamples {
            let turn = trimmedTurn()
            state = .silence
            preRoll = Array(turnSamples.suffix(configuration.paddingSamples))
            turnSamples.removeAll()
            trailingSilenceSamples = 0
            return [.turnEnded(turn)]
        }

        if turnSamples.count >= configuration.maximumTurnSamples {
            let turn = turnSamples
            turnSamples.removeAll()
            trailingSilenceSamples = 0
            return [.turnEnded(turn)]
        }

        return []
    }

    private func trimmedTurn() -> [Float] {
        let excessSilence = max(0, trailingSilenceSamples - configuration.paddingSamples)
        return Array(turnSamples.dropLast(excessSilence))
    }
}
