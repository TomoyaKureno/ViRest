import Foundation

extension Date {
    func startOfWeek(using calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    func isSameDay(as date: Date, using calendar: Calendar = .current) -> Bool {
        calendar.isDate(self, inSameDayAs: date)
    }

    func isYesterday(relativeTo date: Date, using calendar: Calendar = .current) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else {
            return false
        }
        return calendar.isDate(self, inSameDayAs: yesterday)
    }
}

extension Array where Element == SessionCheckIn {
    func sortedByDateDescending() -> [SessionCheckIn] {
        sorted { $0.checkInDate > $1.checkInDate }
    }
}
