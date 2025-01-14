import Foundation
import EventKit
@testable import NovelEventsExtractor

class MockEvent: EventType {
    var title: String!
    var startDate: Date!
    var endDate: Date!
    var calendar: EKCalendar!
    private var mockCalendar: CalendarType
    
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
    
    // Allow updating the calendar and sync it with the EKCalendar
    func setCalendar(_ newCalendar: CalendarType) {
        self.mockCalendar = newCalendar
        self.calendar.title = newCalendar.title
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