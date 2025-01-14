import Foundation
import EventKit
@testable import NovelEventsExtractor

class MockEventStore: EventStoreType {
    var shouldGrantAccess = true
    var mockCalendars: [CalendarType] = []
    var mockEvents: [EventType] = []
    
    func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        return shouldGrantAccess
    }
    
    func calendars(for entityType: EKEntityType) -> [CalendarType] {
        return mockCalendars
    }
    
    func events(matching predicate: NSPredicate) -> [EventType] {
        return mockEvents.filter { event in
            if let datePredicate = predicate as? EKEventSearchPredicate {
                let startDate = datePredicate.startDate
                let endDate = datePredicate.endDate
                let calendars = datePredicate.calendars
                
                // Filter by date range
                guard let eventStart = event.startDate else { return false }
                guard eventStart >= startDate && eventStart <= endDate else {
                    return false
                }
                
                // Filter by calendars if specified
                if let calendars = calendars,
                   let eventCalendar = event.calendar {
                    return calendars.contains { calendar in
                        calendar.title == eventCalendar.title
                    }
                }
                
                return true
            }
            return true
        }
    }
    
    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [CalendarType]?) -> NSPredicate {
        return EKEventSearchPredicate(startDate: startDate, endDate: endDate, calendars: calendars)
    }
}

// Custom predicate class for testing
class EKEventSearchPredicate: NSPredicate {
    let startDate: Date
    let endDate: Date
    let calendars: [CalendarType]?
    
    init(startDate: Date, endDate: Date, calendars: [CalendarType]?) {
        self.startDate = startDate
        self.endDate = endDate
        self.calendars = calendars
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
} 