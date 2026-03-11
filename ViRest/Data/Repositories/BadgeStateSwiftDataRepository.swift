import Foundation

@MainActor
final class BadgeStateSwiftDataRepository: BadgeStateRepository {
    private let store: SwiftDataKeyValueStore

    init(store: SwiftDataKeyValueStore) {
        self.store = store
    }

    func loadState() throws -> BadgeState {
        try store.load(BadgeState.self, forKey: StorageKeys.badgeState) ?? .default
    }

    func saveState(_ state: BadgeState) throws {
        try store.save(state, forKey: StorageKeys.badgeState)
    }
}
