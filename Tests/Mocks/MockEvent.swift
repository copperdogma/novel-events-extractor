import Foundation
import EventKit
@testable import NovelEventsExtractor

class MockEvent: EventType {
    let title: String!
    let startDate: Date!
    let endDate: Date!
    let calendar: EKCalendar!
    private let mockCalendar: CalendarType
    
    init(title: String,
         startDate: Date,
         endDate: Date,
         calendar: CalendarType) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.mockCalendar = calendar
        // Create a mock EKCalendar for compatibility
        let mockEKCalendar = EKCalendar(for: .event, eventStore: EKEventStore())
        mockEKCalendar.setValue(calendar.title, forKey: "title")
        self.calendar = mockEKCalendar
    }
}

// Extension to make MockEvent usable where EKEvent is expected
extension MockEvent: Equatable {
    static func == (lhs: MockEvent, rhs: MockEvent) -> Bool {
        return lhs.title == rhs.title &&
               lhs.startDate == rhs.startDate &&
               lhs.endDate == rhs.endDate &&
               lhs.mockCalendar.title == rhs.mockCalendar.title
    }
} 