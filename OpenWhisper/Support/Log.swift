import os

enum Log {
    static let subsystem = "com.amankumar.openwhisper"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let whisper = Logger(subsystem: subsystem, category: "whisper")
    static let output = Logger(subsystem: subsystem, category: "output")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let models = Logger(subsystem: subsystem, category: "models")
    static let correction = Logger(subsystem: subsystem, category: "correction")
    static let session = Logger(subsystem: subsystem, category: "session")
}
