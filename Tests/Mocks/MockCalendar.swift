import Foundation
import EventKit
@testable import NovelEventsExtractor

class MockCalendar: CalendarType {
    var title: String
    var type: EKCalendarType
    
    init(title: String = "", type: EKCalendarType = .local) {
        self.title = title
        self.type = type
    }
}

// Extension to make MockCalendar usable where EKCalendar is expected
extension MockCalendar: Equatable {
    static func == (lhs: MockCalendar, rhs: MockCalendar) -> Bool {
        return lhs.title == rhs.title && lhs.type == rhs.type
    }
} 