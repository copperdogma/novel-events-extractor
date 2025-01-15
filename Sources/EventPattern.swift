import Foundation
import EventKit

struct EventPattern {
    let title: String
    let dayOfWeek: Int?  // nil for teaching events
    let hour: Int
    let minute: Int
    let calendarTitle: String
    let frequency: Int
    
    var score: Double {
        // Higher frequency means higher score, capped at 1.0
        min(Double(frequency) / 12.0, 1.0)
    }
    
    func isSimilarTo(event: EventType, calendar: Calendar) -> Bool {
        guard let eventStartDate = event.startDate,
              let eventTitle = event.title,
              let eventCalendar = event.calendar else {
            return false
        }
        
        // Calendar must match exactly
        guard eventCalendar.title == calendarTitle else {
            return false
        }
        
        // For teaching events, ignore day of week
        let eventDayOfWeek = calendar.component(.weekday, from: eventStartDate)
        if let patternDayOfWeek = dayOfWeek {
            guard eventDayOfWeek == patternDayOfWeek else {
                return false
            }
        }
        
        // Time must be within 1 hour
        let eventHour = calendar.component(.hour, from: eventStartDate)
        let eventMinute = calendar.component(.minute, from: eventStartDate)
        let eventTotalMinutes = eventHour * 60 + eventMinute
        let patternTotalMinutes = hour * 60 + minute
        let minuteDifference = abs(eventTotalMinutes - patternTotalMinutes)
        guard minuteDifference <= 60 else {
            return false
        }
        
        // Title matching depends on frequency
        if frequency >= 12 {
            // For high-frequency events (monthly or more), allow partial matches
            // but only for titles longer than 5 characters
            if eventTitle.count <= 5 || title.count <= 5 {
                return eventTitle.lowercased() == title.lowercased()
            }
            return eventTitle.lowercased().contains(title.lowercased()) ||
                   title.lowercased().contains(eventTitle.lowercased())
        } else {
            // For low-frequency events, require exact match
            return eventTitle.lowercased() == title.lowercased()
        }
    }
} 