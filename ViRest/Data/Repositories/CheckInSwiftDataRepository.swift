import Foundation

@MainActor
final class CheckInSwiftDataRepository: CheckInRepository {
    private let store: SwiftDataKeyValueStore

    init(store: SwiftDataKeyValueStore) {
        self.store = store
    }

    func loadCheckIns() throws -> [SessionCheckIn] {
        try store.load([SessionCheckIn].self, forKey: StorageKeys.checkIns) ?? []
    }

    func addCheckIn(_ checkIn: SessionCheckIn) throws {
        var all = try loadCheckIns()
        all.append(checkIn)
        all.sort { $0.checkInDate > $1.checkInDate }
        try store.save(all, forKey: StorageKeys.checkIns)
    }
}
