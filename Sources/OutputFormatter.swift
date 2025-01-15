import Foundation
import EventKit

/// OutputFormatter handles formatting and writing the results.
/// Debug output is controlled by `isDebugEnabled` flag - DO NOT REMOVE debug code,
/// it's essential for development and troubleshooting calendar filtering issues.
class OutputFormatter {
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    private var debugOutput: String = ""
    
    /// Controls whether debug information is included in the output
    /// Set to false to hide debug info in production, but keep the code for development
    let isDebugEnabled: Bool
    
    init(isDebugEnabled: Bool = true) {
        self.isDebugEnabled = isDebugEnabled
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE MMM dd"
        dateFormatter.timeZone = TimeZone.current
        
        timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"
        timeFormatter.timeZone = TimeZone.current
    }
    
    func setTimeZone(_ timeZone: TimeZone) {
        dateFormatter.timeZone = timeZone
        timeFormatter.timeZone = timeZone
    }
    
    func addDebug(_ message: String) {
        guard isDebugEnabled else { return }
        debugOutput += message + "\n"
    }
    
    func getDebugOutput() -> String {
        return debugOutput
    }
    
    func formatNovelEvents(_ events: [NovelEvent], lookAheadDays: Int) -> String {
        // Use the formatter's timezone instead of current
        let formatterTimeZone = dateFormatter.timeZone ?? TimeZone.current
        
        // Create a calendar with the formatter's timezone
        var cal = Calendar.current
        cal.timeZone = formatterTimeZone
        
        var output = isDebugEnabled ? debugOutput + "\n" : ""
        output += "Novel events found in next \(lookAheadDays) days:\n\n"
        
        // Add generation timestamp
        let now = Date()
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "EEE yyyy-MM-dd HH:mm:ss zzz"
        timestampFormatter.timeZone = formatterTimeZone
        timestampFormatter.locale = Locale(identifier: "en_US_POSIX")
        output += "Generated: \(timestampFormatter.string(from: now))\n\n"
        
        if events.isEmpty {
            output += "No events found\n"
            return output
        }
        
        // Sort events chronologically by start date
        let sortedEvents = events.sorted { (event1, event2) -> Bool in
            // Handle nil dates by putting them at the end
            guard let date1 = event1.event.startDate else { return false }
            guard let date2 = event2.event.startDate else { return true }
            return date1 < date2
        }
        
        // Format each event
        for novelEvent in sortedEvents {
            let event = novelEvent.event
            
            // Handle nil dates
            guard let startDate = event.startDate,
                  let endDate = event.endDate else {
                // For events with nil dates, just show the title and calendar
                let title = (event.title?.isEmpty ?? true) ? "[Untitled Event]" : event.title!
                let calendarTitle = event.calendar.title
                output += "(No Date) \(title) [\(calendarTitle)]\n"
                if isDebugEnabled {
                    output += "  Reason: \(novelEvent.reason)\n"
                }
                continue
            }
            
            // Check if it's an all-day event by checking if:
            // 1. Start date is at midnight
            // 2. End date is at midnight
            // 3. Duration is a multiple of 24 hours
            let startIsStartOfDay = cal.isDate(startDate, equalTo: cal.startOfDay(for: startDate), toGranularity: .day)
            let endIsStartOfDay = cal.isDate(endDate, equalTo: cal.startOfDay(for: endDate), toGranularity: .day)
            let durationInHours = cal.dateComponents([.hour], from: startDate, to: endDate).hour ?? 0
            let isAllDay = startIsStartOfDay && endIsStartOfDay && (durationInHours % 24 == 0)
            
            // Check if it's a multi-day event
            let isMultiDay = !cal.isDate(startDate, inSameDayAs: endDate)
            
            // Format the event date and time
            let formattedStartDate = dateFormatter.string(from: startDate)
            let startTime = timeFormatter.string(from: startDate)
            
            let dateTimeStr: String
            if isAllDay && isMultiDay {
                // For multi-day all-day events, show date range with (All Day)
                // For all-day events, the end date is exclusive, so subtract one day
                let lastDay = cal.date(byAdding: .day, value: -1, to: endDate)!
                let endDateStr = dateFormatter.string(from: lastDay)
                dateTimeStr = "\(formattedStartDate) (All Day) - \(endDateStr) (All Day)"
            } else if isAllDay {
                dateTimeStr = "\(formattedStartDate) (All Day)"
            } else if isMultiDay {
                let endDateStr = dateFormatter.string(from: endDate)
                let endTime = timeFormatter.string(from: endDate)
                dateTimeStr = "\(formattedStartDate) \(startTime) - \(endDateStr) \(endTime)"
            } else {
                dateTimeStr = "\(formattedStartDate) \(startTime)"
            }
            
            // Handle empty or nil title
            let title = (event.title?.isEmpty ?? true) ? "[Untitled Event]" : event.title!
            let calendarTitle = event.calendar.title
            
            output += "\(dateTimeStr) \(title) [\(calendarTitle)]\n"
            if isDebugEnabled {
                output += "  Reason: \(novelEvent.reason)\n"
            }
        }
        
        return output
    }
    
    func writeToFile(_ content: String, at path: String) throws {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }
} 