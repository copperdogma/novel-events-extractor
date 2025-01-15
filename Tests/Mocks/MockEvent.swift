import Foundation
import EventKit
@testable import NovelEventsExtractor

class MockEvent: EventType {
    var title: String!
    var startDate: Date!
    var endDate: Date!
    var calendar: EKCalendar!
    private var mockCalendar: CalendarType
    
    var isAllDay: Bool {
        guard let start = startDate,
              let end = endDate else {
            return false
        }
        
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startDay)!
        
        return calendar.isDate(start, inSameDayAs: startDay) &&
               calendar.isDate(end, inSameDayAs: endDay) &&
               calendar.isDate(endDay, inSameDayAs: nextDay) &&
               calendar.component(.hour, from: start) == 0 &&
               calendar.component(.minute, from: start) == 0 &&
               calendar.component(.hour, from: end) == 0 &&
               calendar.component(.minute, from: end) == 0
    }
    
    init(title: String? = nil,
         startDate: Date? = nil,
         endDate: Date? = nil,
         calendar: CalendarType? = nil) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.mockCalendar = calendar ?? MockCalendar()
        
        // Create a mock EKCalendar for compatibility
        let mockEKCalendar = EKCalendar(for: .event, eventStore: EKEventStore())
        mockEKCalendar.title = self.mockCalendar.title
        self.calendar = mockEKCalendar
    }
}

// Extension to make MockEvent usable where EKEvent is expected
extension MockEvent: Equatable {
    static func == (lhs: MockEvent, rhs: MockEvent) -> Bool {
        return lhs.title == rhs.title &&
               lhs.startDate == rhs.startDate &&
               lhs.endDate == rhs.endDate &&
               lhs.calendar?.title == rhs.calendar?.title
    }
} 