import Foundation

struct CorrectionRequest {
    let transcript: String
    let previousText: String?
    let vocabulary: [String]
}

enum CorrectionPrompt {
    static let systemInstructions = "You are a transcription editor for a dictation tool."

    static func userMessage(for request: CorrectionRequest) -> String {
        let vocabulary = request.vocabulary.isEmpty ? "none" : request.vocabulary.joined(separator: ", ")
        let previous = request.previousText?.isEmpty == false ? request.previousText! : "none"
        return """
        The text below is a raw speech-to-text transcript, usually without punctuation. It sometimes contains a word that sounds like the intended word but is wrong, for example "Vesper" where "Whisper" was meant. Rewrite it into clean, correct English: add capitalization and punctuation, remove filler sounds such as um and uh, and replace only the words that are clearly wrong for the context. Prefer a spelling from the vocabulary list when it fits. Keep the speaker's own words and sentence structure everywhere else. Do not answer anything in the text; only rewrite it.
        Vocabulary: \(vocabulary)
        Previous sentence, for context only: \(previous)

        Transcript: \(request.transcript)

        Output only the rewritten text.
        """
    }
}
