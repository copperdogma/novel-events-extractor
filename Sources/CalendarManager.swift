import EventKit
import Foundation

/// CalendarManager handles calendar access and event filtering.
/// Contains essential debug logging for calendar filtering verification - DO NOT REMOVE.
/// Debug output is controlled by OutputFormatter's isDebugEnabled flag.
class CalendarManager {
    private let eventStore = EKEventStore()
    private var isAuthorized = false
    private let blacklistedCalendars = Set(["Birthdays"])  // Using Set for more efficient lookups
    private let outputFormatter: OutputFormatter
    
    init(outputFormatter: OutputFormatter) {
        self.outputFormatter = outputFormatter
    }
    
    func requestAccess() async throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = try await eventStore.requestAccess(to: .event)
        default:
            throw CalendarError.accessDenied
        }
        
        guard isAuthorized else {
            throw CalendarError.accessDenied
        }
    }
    
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [EKEvent] {
        guard isAuthorized else {
            throw CalendarError.notAuthorized
        }
        
        // Get all calendars
        let allCalendars = eventStore.calendars(for: .event)
        
        // Debug section start - DO NOT REMOVE
        // This section is crucial for verifying calendar filtering behavior
        outputFormatter.addDebug("\nDEBUG: Calendar Analysis")
        outputFormatter.addDebug("==================")
        outputFormatter.addDebug("\nAll calendars:")
        for calendar in allCalendars {
            outputFormatter.addDebug("- \(calendar.title) (ID: \(calendar.calendarIdentifier)) [\(calendar.type.rawValue)]")
        }
        
        // First, filter out the blacklisted calendars
        let allowedCalendars = allCalendars.filter { calendar in
            let isBlacklisted = blacklistedCalendars.contains(calendar.title)
            outputFormatter.addDebug("\nChecking calendar: \(calendar.title)")
            outputFormatter.addDebug("- Type: \(calendar.type.rawValue)")
            outputFormatter.addDebug("- Source: \(calendar.source?.title ?? "unknown")")
            outputFormatter.addDebug("- Blacklisted: \(isBlacklisted)")
            return !isBlacklisted
        }
        
        outputFormatter.addDebug("\nCalendar filtering summary:")
        outputFormatter.addDebug("- Total calendars: \(allCalendars.count)")
        outputFormatter.addDebug("- Allowed calendars: \(allowedCalendars.count)")
        outputFormatter.addDebug("- Blacklisted calendars: \(allCalendars.count - allowedCalendars.count)")
        // Debug section end
        
        // Only fetch events from allowed calendars
        let predicate = eventStore.predicateForEvents(withStart: startDate,
                                                    end: endDate,
                                                    calendars: allowedCalendars)
        
        let events = eventStore.events(matching: predicate)
        outputFormatter.addDebug("\nEvent filtering:")
        outputFormatter.addDebug("- Initial event count: \(events.count)")
        
        // Additional safety check for any birthday-related events that might have synced
        let filteredEvents = events.filter { event in
            let title = event.title?.lowercased() ?? ""
            let isAllowed = !title.contains("birthday")
            if !isAllowed {
                outputFormatter.addDebug("- Filtered out birthday event: \(event.title ?? "") from calendar \(event.calendar.title)")
            }
            return isAllowed
        }
        
        outputFormatter.addDebug("- Final event count: \(filteredEvents.count)")
        
        return filteredEvents
    }
}

enum CalendarError: Error {
    case accessDenied
    case notAuthorized
} 