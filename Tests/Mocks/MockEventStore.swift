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
            guard let eventEndDate = event.endDate else { return false }
            guard let eventCalendar = event.calendar else { return false }
            
            let calendar = Calendar.current
            
            // Check if it's an all-day event
            let isAllDayEvent = calendar.isDate(eventStartDate, equalTo: calendar.startOfDay(for: eventStartDate), toGranularity: .day) &&
                               calendar.isDate(eventEndDate, equalTo: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: eventStartDate))!, toGranularity: .day)
            
            // For all-day events, check if the start date is within the range
            if isAllDayEvent {
                let eventDay = calendar.startOfDay(for: eventStartDate)
                let rangeStart = calendar.startOfDay(for: startDate)
                let rangeEnd = calendar.startOfDay(for: endDate)
                let isInRange = eventDay >= rangeStart && eventDay < rangeEnd
                
                // Check if event's calendar is in the allowed calendars list
                let isAllowedCalendar = calendars?.contains { calendar in
                    calendar.title == eventCalendar.title
                } ?? true
                
                return isInRange && isAllowedCalendar
            }
            
            // For regular events, check if the start date is within the range
            // Historical boundary is exclusive (>), future boundary is inclusive (<=)
            let isInDateRange = eventStartDate >= startDate && eventStartDate < endDate
            
            // Check if event's calendar is in the allowed calendars list
            let isAllowedCalendar = calendars?.contains { calendar in
                calendar.title == eventCalendar.title
            } ?? true
            
            return isInDateRange && isAllowedCalendar
        }
    }
} 