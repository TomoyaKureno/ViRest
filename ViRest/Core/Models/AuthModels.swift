import Foundation

enum AuthProvider: String, Codable {
    case apple
    case google
}

struct AuthUser: Codable, Equatable {
    var id: String
    var email: String?
    var displayName: String
    var provider: AuthProvider
}

enum AppAuthState: Equatable {
    case signedOut
    case signedIn(AuthUser)
}
