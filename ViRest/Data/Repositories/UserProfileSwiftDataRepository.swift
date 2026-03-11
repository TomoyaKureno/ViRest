import Foundation

@MainActor
final class UserProfileSwiftDataRepository: UserProfileRepository {
    private let store: SwiftDataKeyValueStore

    init(store: SwiftDataKeyValueStore) {
        self.store = store
    }

    func loadProfile() throws -> UserProfileInput? {
        try store.load(UserProfileInput.self, forKey: StorageKeys.userProfile)
    }

    func saveProfile(_ profile: UserProfileInput) throws {
        try store.save(profile, forKey: StorageKeys.userProfile)
    }
}
