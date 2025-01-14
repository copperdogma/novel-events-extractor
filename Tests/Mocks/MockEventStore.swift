import EventKit
@testable import NovelEventsExtractor

class MockEventStore: EventStoreType {
    var shouldGrantAccess = true
    var shouldThrowOnFetch = false
    var requestAccessCalled = false
    var getCalendarsCalled = false
    var getEventsCalled = false
    
    var calendars: [CalendarType] = []
    var events: [EventType] = []
    
    func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        requestAccessCalled = true
        if !shouldGrantAccess {
            throw CalendarError.accessDenied
        }
        return shouldGrantAccess
    }
    
    func getCalendars(for entityType: EKEntityType) -> [CalendarType] {
        getCalendarsCalled = true
        return calendars
    }
    
    func getEvents(matching predicate: NSPredicate) throws -> [EventType] {
        getEventsCalled = true
        if shouldThrowOnFetch {
            throw CalendarError.accessDenied
        }
        return events.filter { event in
            predicate.evaluate(with: event)
        }
    }
    
    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [CalendarType]?) -> NSPredicate {
        return NSPredicate { event, _ in
            guard let event = event as? EventType else { return false }
            guard let eventStartDate = event.startDate else { return false }
            guard let eventCalendar = event.calendar else { return false }
            
            // Check if event is within date range (exclusive)
            let isInDateRange = eventStartDate > startDate && eventStartDate < endDate
            
            // Check if event's calendar is in the allowed calendars list
            let isAllowedCalendar = calendars?.contains { calendar in
                calendar.title == eventCalendar.title
            } ?? true
            
            return isInDateRange && isAllowedCalendar
        }
    }
} 