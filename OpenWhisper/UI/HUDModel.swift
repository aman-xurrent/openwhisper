import Foundation
import Observation

@MainActor
@Observable
final class HUDModel {
    enum MessageKind {
        case success
        case warning
        case info
    }

    enum Phase: Equatable {
        case hidden
        case recording
        case transcribing
        case message(String, MessageKind)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.hidden, .hidden), (.recording, .recording), (.transcribing, .transcribing):
                return true
            case let (.message(leftText, _), .message(rightText, _)):
                return leftText == rightText
            default:
                return false
            }
        }
    }

    static let levelHistoryLength = 28
    static let levelGain: Float = 6

    var phase: Phase = .hidden
    var levels: [Float] = Array(repeating: 0, count: HUDModel.levelHistoryLength)
    var hotKeyDescription = ""
    var detail = ""

    func push(level: Float) {
        levels.removeFirst()
        levels.append(min(1, level * Self.levelGain))
    }

    func resetLevels() {
        levels = Array(repeating: 0, count: Self.levelHistoryLength)
    }
}
