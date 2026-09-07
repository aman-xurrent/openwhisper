import Foundation

enum WhisperModelFamily: String, CaseIterable, Identifiable {
    case tiny
    case base
    case small
    case medium
    case large

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var summary: String {
        switch self {
        case .tiny: return "Fastest, rough accuracy. Fine for short commands."
        case .base: return "Fast with decent accuracy."
        case .small: return "Good balance of speed and accuracy for dictation."
        case .medium: return "High accuracy, noticeably slower."
        case .large: return "Best accuracy. Turbo variants keep the quality with a much faster decoder."
        }
    }
}

struct WhisperModel: Identifiable, Hashable, DownloadableAsset {
    static let downloadBaseURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/")!
    static let englishSuffix = ".en"
    static let quantizationMarker = "-q"

    let name: String
    let approximateSizeMB: Int
    let summary: String

    var id: String { name }
    var fileName: String { "ggml-\(name).bin" }
    var isEnglishOnly: Bool { name.contains(Self.englishSuffix) }
    var downloadURL: URL { Self.downloadBaseURL.appendingPathComponent(fileName) }

    var family: WhisperModelFamily {
        WhisperModelFamily.allCases.first { name.hasPrefix($0.rawValue) } ?? .large
    }

    var quantization: String? {
        guard let range = name.range(of: Self.quantizationMarker, options: .backwards) else { return nil }
        return String(name[range.lowerBound...].dropFirst())
    }

    var languageDescription: String {
        isEnglishOnly ? "English" : "Multilingual"
    }

    var sizeDescription: String {
        approximateSizeMB >= 1_000
            ? String(format: "%.1f GB", Double(approximateSizeMB) / 1_000)
            : "\(approximateSizeMB) MB"
    }

    static let catalog: [WhisperModel] = [
        WhisperModel(name: "tiny.en", approximateSizeMB: 78, summary: "Full precision."),
        WhisperModel(name: "tiny.en-q8_0", approximateSizeMB: 44, summary: "8-bit. Same accuracy, smaller file."),
        WhisperModel(name: "tiny.en-q5_1", approximateSizeMB: 32, summary: "5-bit. Smallest, slight accuracy loss."),
        WhisperModel(name: "tiny", approximateSizeMB: 78, summary: "Full precision."),
        WhisperModel(name: "tiny-q8_0", approximateSizeMB: 44, summary: "8-bit. Same accuracy, smaller file."),
        WhisperModel(name: "tiny-q5_1", approximateSizeMB: 32, summary: "5-bit. Smallest, slight accuracy loss."),

        WhisperModel(name: "base.en", approximateSizeMB: 148, summary: "Full precision."),
        WhisperModel(name: "base.en-q8_0", approximateSizeMB: 82, summary: "8-bit. Same accuracy, smaller file."),
        WhisperModel(name: "base.en-q5_1", approximateSizeMB: 60, summary: "5-bit. Smallest, slight accuracy loss."),
        WhisperModel(name: "base", approximateSizeMB: 148, summary: "Full precision."),
        WhisperModel(name: "base-q8_0", approximateSizeMB: 82, summary: "8-bit. Same accuracy, smaller file."),
        WhisperModel(name: "base-q5_1", approximateSizeMB: 60, summary: "5-bit. Smallest, slight accuracy loss."),

        WhisperModel(name: "small.en", approximateSizeMB: 488, summary: "Full precision. Default."),
        WhisperModel(name: "small.en-q8_0", approximateSizeMB: 264, summary: "8-bit. Same accuracy at half the size."),
        WhisperModel(name: "small.en-q5_1", approximateSizeMB: 190, summary: "5-bit. Smallest, slight accuracy loss."),
        WhisperModel(name: "small", approximateSizeMB: 488, summary: "Full precision."),
        WhisperModel(name: "small-q8_0", approximateSizeMB: 264, summary: "8-bit. Same accuracy at half the size."),
        WhisperModel(name: "small-q5_1", approximateSizeMB: 190, summary: "5-bit. Smallest, slight accuracy loss."),

        WhisperModel(name: "medium.en", approximateSizeMB: 1_534, summary: "Full precision."),
        WhisperModel(name: "medium.en-q8_0", approximateSizeMB: 823, summary: "8-bit. Same accuracy at half the size."),
        WhisperModel(name: "medium.en-q5_0", approximateSizeMB: 539, summary: "5-bit. Smallest, slight accuracy loss."),
        WhisperModel(name: "medium", approximateSizeMB: 1_534, summary: "Full precision."),
        WhisperModel(name: "medium-q8_0", approximateSizeMB: 823, summary: "8-bit. Same accuracy at half the size."),
        WhisperModel(name: "medium-q5_0", approximateSizeMB: 539, summary: "5-bit. Smallest, slight accuracy loss."),

        WhisperModel(name: "large-v3-turbo", approximateSizeMB: 1_625, summary: "Large-v3 quality, decoder about 8x faster. Best pick in this group."),
        WhisperModel(name: "large-v3-turbo-q8_0", approximateSizeMB: 874, summary: "8-bit turbo. Same accuracy, smaller file."),
        WhisperModel(name: "large-v3-turbo-q5_0", approximateSizeMB: 574, summary: "5-bit turbo. Best accuracy per MB."),
        WhisperModel(name: "large-v3", approximateSizeMB: 3_095, summary: "Full precision. Most accurate, slowest."),
        WhisperModel(name: "large-v3-q5_0", approximateSizeMB: 1_081, summary: "5-bit large-v3."),
        WhisperModel(name: "large-v2", approximateSizeMB: 3_095, summary: "Previous generation. Some prefer it for fewer hallucinations."),
        WhisperModel(name: "large-v2-q8_0", approximateSizeMB: 1_656, summary: "8-bit large-v2."),
        WhisperModel(name: "large-v2-q5_0", approximateSizeMB: 1_081, summary: "5-bit large-v2."),
        WhisperModel(name: "large-v1", approximateSizeMB: 3_095, summary: "Original large. Superseded by v2 and v3."),
    ]

    static let recommended = catalog.first { $0.name == "large-v3" }!

    static func named(_ name: String) -> WhisperModel? {
        catalog.first { $0.name == name }
    }

    static func models(in family: WhisperModelFamily) -> [WhisperModel] {
        catalog.filter { $0.family == family }
    }
}
