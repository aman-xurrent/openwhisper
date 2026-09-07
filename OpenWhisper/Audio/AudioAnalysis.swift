import Foundation

enum AudioAnalysis {
    static let speechWindowSize = 1_600
    static let speechThreshold: Float = 0.0015
    static let silenceFloor: Float = 0.0006

    static func rootMeanSquare(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }

    static func peakRootMeanSquare(_ samples: [Float], windowSize: Int = speechWindowSize) -> Float {
        guard !samples.isEmpty, windowSize > 0 else { return 0 }
        var peak: Float = 0
        var start = 0
        while start < samples.count {
            let end = min(start + windowSize, samples.count)
            peak = max(peak, rootMeanSquare(Array(samples[start..<end])))
            start = end
        }
        return peak
    }

    static func containsSpeech(_ samples: [Float]) -> Bool {
        peakRootMeanSquare(samples) >= speechThreshold
    }

    static func isEffectivelySilent(_ samples: [Float]) -> Bool {
        peakRootMeanSquare(samples) < silenceFloor
    }
}
