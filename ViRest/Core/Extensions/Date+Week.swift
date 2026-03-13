//
//  Date+Week.swift
//  ViRest
//
//  Created by Joshua Valentine Manik on 13/03/26.
//

import Foundation

extension Date {
    func startOfWeek() -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2  // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
}
