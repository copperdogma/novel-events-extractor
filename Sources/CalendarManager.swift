import EventKit
import Foundation

protocol EventStoreType {
    func requestAccess(to entityType: EKEntityType) async throws -> Bool
    func getCalendars(for entityType: EKEntityType) -> [CalendarType]
    func getEvents(matching predicate: NSPredicate) throws -> [EventType]
    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [CalendarType]?) -> NSPredicate
}

protocol CalendarType {
    var title: String { get }
    var type: EKCalendarType { get }
}

protocol EventType {
    var title: String! { get }
    var startDate: Date! { get }
    var endDate: Date! { get }
    var calendar: EKCalendar! { get }
    var isAllDay: Bool { get }
}

// Make EKEventStore conform to EventStoreType
extension EKEventStore: EventStoreType {
    func getCalendars(for entityType: EKEntityType) -> [CalendarType] {
        return calendars(for: entityType)
    }
    
    func getEvents(matching predicate: NSPredicate) throws -> [EventType] {
        return events(matching: predicate)
    }
    
    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [CalendarType]?) -> NSPredicate {
        return predicateForEvents(withStart: startDate, 
                                end: endDate, 
                                calendars: calendars as? [EKCalendar])
    }
}

// Make EKCalendar conform to CalendarType
extension EKCalendar: CalendarType {}

// Make EKEvent conform to EventType
extension EKEvent: EventType {}

/// CalendarManager handles calendar access and event filtering.
/// Contains essential debug logging for calendar filtering verification - DO NOT REMOVE.
/// Debug output is controlled by OutputFormatter's isDebugEnabled flag.
class CalendarManager {
    private let eventStore: EventStoreType
    private let outputFormatter: OutputFormatter
    private let blacklistedCalendars: Set<String>
    private let whitelistedCalendars: Set<String>?
    private let daysToLookAhead: Int
    
    init(eventStore: EventStoreType,
         outputFormatter: OutputFormatter,
         blacklistedCalendars: Set<String> = [],
         whitelistedCalendars: Set<String>? = nil,
         daysToLookAhead: Int = 14) {
        self.eventStore = eventStore
        self.outputFormatter = outputFormatter
        self.blacklistedCalendars = blacklistedCalendars
        self.whitelistedCalendars = whitelistedCalendars
        self.daysToLookAhead = daysToLookAhead
    }
    
    func requestAccess() async throws {
        let granted = try await eventStore.requestAccess(to: .event)
        guard granted else {
            throw CalendarError.accessDenied
        }
        
        // Log available calendars and their status
        let calendars = eventStore.getCalendars(for: .event)
        outputFormatter.addDebug("\nAvailable calendars:")
        for calendar in calendars {
            let status = if blacklistedCalendars.contains(calendar.title) {
                "blacklisted"
            } else if let whitelist = whitelistedCalendars {
                whitelist.contains(calendar.title) ? "whitelisted" : "excluded"
            } else {
                "included"
            }
            outputFormatter.addDebug("- \(calendar.title) (\(status))")
        }
    }
    
    func fetchHistoricalEvents() async throws -> [EventType] {
        let now = Date()
        let calendar = Calendar.current
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
        return try await fetchEvents(from: oneYearAgo, to: now)
    }
    
    func fetchUpcomingEvents() async throws -> [EventType] {
        let now = Date()
        let calendar = Calendar.current
        let lookAheadDate = calendar.date(byAdding: .day, value: daysToLookAhead, to: now)!
        return try await fetchEvents(from: now, to: lookAheadDate)
    }
    
    private func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [EventType] {
        let calendars = eventStore.getCalendars(for: .event)
        let filteredCalendars = calendars.filter { calendar in
            // If calendar is blacklisted, exclude it
            if blacklistedCalendars.contains(calendar.title) {
                return false
            }
            
            // If whitelist exists, only include calendars in the whitelist
            if let whitelist = whitelistedCalendars {
                return whitelist.contains(calendar.title)
            }
            
            // If no whitelist, include all non-blacklisted calendars
            return true
        }
        
        outputFormatter.addDebug("\nFetching events from \(filteredCalendars.count) calendars")
        
        let predicate = eventStore.predicateForEvents(withStart: startDate,
                                                    end: endDate,
                                                    calendars: filteredCalendars)
        
        let events = try eventStore.getEvents(matching: predicate)
        outputFormatter.addDebug("Found \(events.count) events")
        
        // Filter events based on calendar filtering rules
        let filteredEvents = events.filter { event in
            guard let calendar = event.calendar else { return false }
            
            // If calendar is blacklisted, exclude it
            if blacklistedCalendars.contains(calendar.title) {
                return false
            }
            
            // If whitelist exists, only include calendars in the whitelist
            if let whitelist = whitelistedCalendars {
                return whitelist.contains(calendar.title)
            }
            
            // If no whitelist, include all non-blacklisted calendars
            return true
        }
        
        // Sort events chronologically by start date
        return filteredEvents.sorted { 
            guard let date1 = $0.startDate, let date2 = $1.startDate else { return false }
            return date1 < date2 
        }
    }
}

enum CalendarError: Error {
    case accessDenied
} 