import AVFoundation
import XCTest
@testable import OpenWhisper

enum AudioFixtures {
    static func loadMonoSixteenKilohertz(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let targetFormat = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(WhisperEngine.sampleRate),
            channels: 1,
            interleaved: false
        ))
        let sourceBuffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: sourceBuffer)

        let converter = try XCTUnwrap(AVAudioConverter(from: file.processingFormat, to: targetFormat))
        let ratio = targetFormat.sampleRate / file.processingFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * ratio) + 1
        let targetBuffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity))

        var didSupplyInput = false
        var conversionError: NSError?
        converter.convert(to: targetBuffer, error: &conversionError) { _, outStatus in
            if didSupplyInput {
                outStatus.pointee = .endOfStream
                return nil
            }
            didSupplyInput = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }
        if let conversionError { throw conversionError }

        let channel = try XCTUnwrap(targetBuffer.floatChannelData)
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(targetBuffer.frameLength)))
    }
}
