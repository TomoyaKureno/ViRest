import Foundation

enum AppError: LocalizedError {
    case invalidState(String)
    case persistence(String)
    case healthKit(String)
    case auth(String)

    var errorDescription: String? {
        switch self {
        case let .invalidState(message):
            return message
        case let .persistence(message):
            return message
        case let .healthKit(message):
            return message
        case let .auth(message):
            return message
        }
    }
}
