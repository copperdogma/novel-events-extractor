import EventKit
@testable import NovelEventsExtractor

class MockEventStore: EventStoreType {
    var shouldGrantAccess = true
    var shouldThrowOnFetch = false
    var calendars: [CalendarType] = []
    var events: [EventType] = []
    
    // Tracking properties
    var getCalendarsCalled = false
    var requestAccessCalled = false
    var lastStartDate: Date?
    var lastEndDate: Date?
    private var lastPredicate: NSPredicate?
    
    func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        requestAccessCalled = true
        return shouldGrantAccess
    }
    
    func getCalendars(for entityType: EKEntityType) -> [CalendarType] {
        getCalendarsCalled = true
        return calendars
    }
    
    func getEvents(matching predicate: NSPredicate) throws -> [EventType] {
        if shouldThrowOnFetch {
            throw CalendarError.accessDenied
        }
        
        // Filter events based on the last predicate's parameters
        guard let startDate = lastStartDate,
              let endDate = lastEndDate else {
            return []
        }
        
        return events.filter { event in
            guard let eventStartDate = event.startDate,
                  let eventEndDate = event.endDate else { return false }
            
            // For all-day events, include them if they overlap with the range
            if event.isAllDay {
                let eventStartDay = Calendar.current.startOfDay(for: eventStartDate)
                let eventEndDay = Calendar.current.startOfDay(for: eventEndDate)
                let rangeStartDay = Calendar.current.startOfDay(for: startDate)
                let rangeEndDay = Calendar.current.startOfDay(for: endDate)
                
                return eventStartDay <= rangeEndDay && eventEndDay >= rangeStartDay
            }
            
            // For regular events, include if they start within the range
            return eventStartDate >= startDate && eventStartDate < endDate
        }
    }
    
    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [CalendarType]?) -> NSPredicate {
        lastStartDate = startDate
        lastEndDate = endDate
        return NSPredicate { event, _ in
            guard let event = event as? EventType,
                  let eventStartDate = event.startDate,
                  let eventEndDate = event.endDate,
                  let eventCalendar = event.calendar else {
                return false
            }
            
            // Check if event's calendar is in the allowed calendars list
            if let allowedCalendars = calendars {
                let isAllowedCalendar = allowedCalendars.contains { calendar in
                    calendar.title == eventCalendar.title
                }
                guard isAllowedCalendar else { return false }
            }
            
            // For all-day events, include them if they overlap with the range
            if event.isAllDay {
                let eventStartDay = Calendar.current.startOfDay(for: eventStartDate)
                let eventEndDay = Calendar.current.startOfDay(for: eventEndDate)
                let rangeStartDay = Calendar.current.startOfDay(for: startDate)
                let rangeEndDay = Calendar.current.startOfDay(for: endDate)
                
                return eventStartDay <= rangeEndDay && eventEndDay >= rangeStartDay
            }
            
            // For regular events, include if they start within the range
            return eventStartDate >= startDate && eventStartDate < endDate
        }
    }
} 