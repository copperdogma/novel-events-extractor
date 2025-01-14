import EventKit
import Foundation

/// CalendarManager handles calendar access and event filtering.
/// Contains essential debug logging for calendar filtering verification - DO NOT REMOVE.
/// Debug output is controlled by OutputFormatter's isDebugEnabled flag.
class CalendarManager {
    private let eventStore = EKEventStore()
    private let outputFormatter: OutputFormatter
    private let blacklistedCalendars: Set<String>
    private let whitelistedCalendars: Set<String>?
    
    init(outputFormatter: OutputFormatter, blacklistedCalendars: Set<String> = [], whitelistedCalendars: Set<String>? = nil) {
        self.outputFormatter = outputFormatter
        self.blacklistedCalendars = blacklistedCalendars
        self.whitelistedCalendars = whitelistedCalendars
    }
    
    func requestAccess() async throws {
        let granted = try await eventStore.requestAccess(to: .event)
        guard granted else {
            throw CalendarError.accessDenied
        }
        
        // Log available calendars and their status
        let calendars = eventStore.calendars(for: .event)
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
    
    func fetchHistoricalEvents() async throws -> [EKEvent] {
        let now = Date()
        let calendar = Calendar.current
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
        return try await fetchEvents(from: oneYearAgo, to: now)
    }
    
    func fetchUpcomingEvents() async throws -> [EKEvent] {
        let now = Date()
        let calendar = Calendar.current
        let twoWeeksAhead = calendar.date(byAdding: .day, value: 14, to: now)!
        return try await fetchEvents(from: now, to: twoWeeksAhead)
    }
    
    private func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [EKEvent] {
        let calendars = eventStore.calendars(for: .event)
        let filteredCalendars = calendars.filter { calendar in
            // If calendar is blacklisted, exclude it
            guard !blacklistedCalendars.contains(calendar.title) else {
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
        
        let events = eventStore.events(matching: predicate)
        outputFormatter.addDebug("Found \(events.count) events")
        return events
    }
}

enum CalendarError: Error {
    case accessDenied
} 