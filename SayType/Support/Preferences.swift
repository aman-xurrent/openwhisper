import Foundation
import Observation

@MainActor
@Observable
final class Preferences {
    static let shared = Preferences()
    static let didChange = Notification.Name("com.amankumar.saytype.preferencesDidChange")
    static let changedKeyUserInfoKey = "changedKey"

    enum Key: String {
        case hotKey
        case selectedModelName
        case language
        case playSounds
        case appendTrailingSpace
        case useGPU
        case turnMode
        case pauseSeconds
        case noiseSuppression
        case correctionEnabled
        case correctionModelName
        case vocabulary
        case replacements
    }

    static let defaultLanguage = "en"
    static let defaultPauseSeconds = 0.8
    static let pauseSecondsRange = 0.4...1.5

    private let defaults: UserDefaults

    var hotKey: KeyCombo {
        didSet { save(hotKey, for: .hotKey) }
    }

    var selectedModelName: String {
        didSet { save(selectedModelName, for: .selectedModelName) }
    }

    var language: String {
        didSet { save(language, for: .language) }
    }

    var playSounds: Bool {
        didSet { save(playSounds, for: .playSounds) }
    }

    var appendTrailingSpace: Bool {
        didSet { save(appendTrailingSpace, for: .appendTrailingSpace) }
    }

    var useGPU: Bool {
        didSet { save(useGPU, for: .useGPU) }
    }

    var turnMode: Bool {
        didSet { save(turnMode, for: .turnMode) }
    }

    var pauseSeconds: Double {
        didSet { save(pauseSeconds, for: .pauseSeconds) }
    }

    var noiseSuppression: Bool {
        didSet { save(noiseSuppression, for: .noiseSuppression) }
    }

    var correctionEnabled: Bool {
        didSet { save(correctionEnabled, for: .correctionEnabled) }
    }

    var correctionModelName: String {
        didSet { save(correctionModelName, for: .correctionModelName) }
    }

    var vocabulary: String {
        didSet { save(vocabulary, for: .vocabulary) }
    }

    var replacements: String {
        didSet { save(replacements, for: .replacements) }
    }

    var selectedModel: WhisperModel {
        WhisperModel.named(selectedModelName) ?? .recommended
    }

    var correctionModel: CorrectionModel {
        CorrectionModel.named(correctionModelName) ?? .recommended
    }

    var replacementRules: [ReplacementRule] {
        TranscriptReplacer.rules(from: replacements)
    }

    var vocabularyTerms: [String] {
        vocabulary
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hotKey = Self.load(KeyCombo.self, for: .hotKey, from: defaults) ?? .defaultDictation
        selectedModelName = defaults.string(forKey: Key.selectedModelName.rawValue) ?? WhisperModel.recommended.name
        language = defaults.string(forKey: Key.language.rawValue) ?? Self.defaultLanguage
        playSounds = defaults.object(forKey: Key.playSounds.rawValue) as? Bool ?? true
        appendTrailingSpace = defaults.bool(forKey: Key.appendTrailingSpace.rawValue)
        useGPU = defaults.object(forKey: Key.useGPU.rawValue) as? Bool ?? true
        turnMode = defaults.object(forKey: Key.turnMode.rawValue) as? Bool ?? true
        pauseSeconds = defaults.object(forKey: Key.pauseSeconds.rawValue) as? Double ?? Self.defaultPauseSeconds
        noiseSuppression = defaults.object(forKey: Key.noiseSuppression.rawValue) as? Bool ?? false
        correctionEnabled = defaults.object(forKey: Key.correctionEnabled.rawValue) as? Bool ?? true
        correctionModelName = defaults.string(forKey: Key.correctionModelName.rawValue) ?? CorrectionModel.recommended.name
        vocabulary = defaults.string(forKey: Key.vocabulary.rawValue) ?? ""
        replacements = defaults.string(forKey: Key.replacements.rawValue) ?? ""
    }

    private func save<Value: Encodable>(_ value: Value, for key: Key) {
        if let encoded = try? JSONEncoder().encode(value) {
            defaults.set(encoded, forKey: key.rawValue)
        }
        notify(key)
    }

    private func save(_ value: String, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
        notify(key)
    }

    private func save(_ value: Bool, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
        notify(key)
    }

    private func save(_ value: Double, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
        notify(key)
    }

    private func notify(_ key: Key) {
        NotificationCenter.default.post(
            name: Self.didChange,
            object: self,
            userInfo: [Self.changedKeyUserInfoKey: key]
        )
    }

    private static func load<Value: Decodable>(_ type: Value.Type, for key: Key, from defaults: UserDefaults) -> Value? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
