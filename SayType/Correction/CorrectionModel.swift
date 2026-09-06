import Foundation

struct CorrectionModel: Identifiable, Hashable, DownloadableAsset {
    let name: String
    let fileName: String
    let approximateSizeMB: Int
    let summary: String
    let downloadURL: URL

    var id: String { name }

    var sizeDescription: String {
        approximateSizeMB >= 1_000
            ? String(format: "%.1f GB", Double(approximateSizeMB) / 1_000)
            : "\(approximateSizeMB) MB"
    }

    static let catalog: [CorrectionModel] = [
        CorrectionModel(
            name: "qwen2.5-1.5b-instruct-q4_k_m",
            fileName: "qwen2.5-1.5b-instruct-q4_k_m.gguf",
            approximateSizeMB: 1_117,
            summary: "Fastest. Good at punctuation and casing, weaker at misheard words.",
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf")!
        ),
        CorrectionModel(
            name: "qwen2.5-3b-instruct-q4_k_m",
            fileName: "qwen2.5-3b-instruct-q4_k_m.gguf",
            approximateSizeMB: 2_105,
            summary: "Default. About a second per sentence on Apple silicon.",
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf")!
        ),
        CorrectionModel(
            name: "qwen2.5-7b-instruct-q4_k_m",
            fileName: "Qwen2.5-7B-Instruct-Q4_K_M.gguf",
            approximateSizeMB: 4_683,
            summary: "Best corrections, about twice the wait. Needs 16 GB of memory or more.",
            downloadURL: URL(string: "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf")!
        ),
    ]

    static let recommended = catalog.first { $0.name == "qwen2.5-3b-instruct-q4_k_m" }!

    static func named(_ name: String) -> CorrectionModel? {
        catalog.first { $0.name == name }
    }
}
