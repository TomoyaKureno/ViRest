import Foundation

@MainActor
final class BadgeStateSwiftDataRepository: BadgeStateRepository {
    private let store: SwiftDataKeyValueStore

    init(store: SwiftDataKeyValueStore) {
        self.store = store
    }

    func loadState() throws -> BadgeState {
        if var loaded = try store.load(BadgeState.self, forKey: StorageKeys.badgeState) {
            let changed = loaded.normalizeRandomCriteriaIfNeeded()
            if changed {
                try store.save(loaded, forKey: StorageKeys.badgeState)
            }
            return loaded
        }

        let initial = BadgeState.default
        try store.save(initial, forKey: StorageKeys.badgeState)
        return initial
    }

    func saveState(_ state: BadgeState) throws {
        var normalized = state
        _ = normalized.normalizeRandomCriteriaIfNeeded()
        try store.save(normalized, forKey: StorageKeys.badgeState)
    }
}
