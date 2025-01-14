import EventKit
@testable import NovelEventsExtractor

class MockEventStore: EventStoreType {
    var shouldGrantAccess = true
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
    
    func getEvents(matching predicate: NSPredicate) -> [EventType] {
        getEventsCalled = true
        return events
    }
    
    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [CalendarType]?) -> NSPredicate {
        return NSPredicate(value: true)
    }
} 