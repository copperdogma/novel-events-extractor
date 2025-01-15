import EventKit
import Foundation

struct EventPattern {
    let dayOfWeek: Int
    let timeOfDay: Date
    let title: String
    let calendar: String
    let frequency: Int
    
    var score: Double {
        // Simple scoring based on frequency
        Double(frequency) / 52.0  // Normalize against weekly occurrence
    }
    
    // Check if this pattern is similar to another event
    func isSimilarTo(event: EventType, calendar: Calendar) -> Bool {
        let eventTitle = event.title?.lowercased() ?? ""
        let patternTitle = title.lowercased()
        
        // For low-frequency events (less than monthly), require exact title match
        let titleMatches = if frequency < 12 {
            patternTitle == eventTitle
        } else {
            // For frequent events, allow more flexible matching
            patternTitle == eventTitle || 
            (patternTitle.contains(eventTitle) && eventTitle.count > 5) || 
            (eventTitle.contains(patternTitle) && patternTitle.count > 5)
        }
        
        // Check if times are within 1 hour of each other
        let timeComponents = calendar.dateComponents([.hour, .minute], from: event.startDate)
        let patternTime = calendar.dateComponents([.hour, .minute], from: timeOfDay)
        let hourDiff = abs((timeComponents.hour ?? 0) - (patternTime.hour ?? 0))
        
        // Check if it's the same day of the week (ignore for teaching events)
        let eventDayOfWeek = calendar.component(.weekday, from: event.startDate)
        let dayMatches = patternTitle.contains("teaching") || eventDayOfWeek == dayOfWeek
        
        // Consider events similar if they're in the same calendar, have similar titles,
        // occur at similar times, and on the same day of the week (unless it's a teaching event)
        return self.calendar == event.calendar.title &&
               titleMatches &&
               hourDiff <= 1 &&
               dayMatches
    }
}

class PatternDetector {
    private var patterns: [EventPattern] = []
    private let outputFormatter: OutputFormatter
    
    init(outputFormatter: OutputFormatter) {
        self.outputFormatter = outputFormatter
    }
    
    private func createPatternKey(title: String, dayOfWeek: Int, hour: Int, minute: Int, calendarTitle: String) -> String {
        // For teaching events, ignore the day of week to group them together regardless of day
        if title.lowercased().contains("teaching") {
            return "\(hour):\(minute)|\(title)|\(calendarTitle)"
        }
        return "\(dayOfWeek)|\(hour):\(minute)|\(title)|\(calendarTitle)"
    }
    
    func analyzeEvents(_ events: [EventType]) {
        var patternMap: [String: Int] = [:]
        let calendar = Calendar.current
        
        outputFormatter.addDebug("\nAnalyzing event patterns:")
        
        for event in events {
            guard let startDate = event.startDate,
                  let title = event.title,
                  let calendarTitle = event.calendar?.title else {
                continue
            }
            
            let dayOfWeek = calendar.component(.weekday, from: startDate)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: startDate)
            let hour = timeComponents.hour ?? 0
            let minute = timeComponents.minute ?? 0
            
            let key = createPatternKey(title: title,
                                     dayOfWeek: dayOfWeek,
                                     hour: hour,
                                     minute: minute,
                                     calendarTitle: calendarTitle)
            
            patternMap[key, default: 0] += 1
            
            // Debug Nicole teaching events
            if title.lowercased().contains("nicole teaching") {
                outputFormatter.addDebug("\nFound teaching event:")
                outputFormatter.addDebug("- Title: \(title)")
                outputFormatter.addDebug("- Day: \(dayOfWeek)")
                outputFormatter.addDebug("- Time: \(hour):\(minute)")
                outputFormatter.addDebug("- Calendar: \(calendarTitle)")
                outputFormatter.addDebug("- Pattern key: \(key)")
                outputFormatter.addDebug("- Current frequency: \(patternMap[key]!)")
            }
        }
        
        // Convert to patterns
        patterns = patternMap.compactMap { key, frequency in
            let components = key.split(separator: "|")
            
            // Handle teaching events (which don't include day of week in key)
            if components.count == 3 {
                let timeComponents = String(components[0]).split(separator: ":")
                guard timeComponents.count == 2,
                      let hour = Int(timeComponents[0]),
                      let minute = Int(timeComponents[1]) else {
                    return nil
                }
                
                let timeDate = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
                
                // Use a default day of week since it doesn't matter for teaching events
                return EventPattern(
                    dayOfWeek: 1, // Use Sunday as default
                    timeOfDay: timeDate,
                    title: String(components[1]),
                    calendar: String(components[2]),
                    frequency: frequency
                )
            }
            
            // Handle regular events (which include day of week)
            guard components.count == 4,
                  let dayOfWeek = Int(components[0]) else {
                return nil
            }
            
            let timeComponents = String(components[1]).split(separator: ":")
            guard timeComponents.count == 2,
                  let hour = Int(timeComponents[0]),
                  let minute = Int(timeComponents[1]) else {
                return nil
            }
            
            let timeDate = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
            
            let pattern = EventPattern(
                dayOfWeek: dayOfWeek,
                timeOfDay: timeDate,
                title: String(components[2]),
                calendar: String(components[3]),
                frequency: frequency
            )
            
            // Debug patterns for Nicole teaching
            if pattern.title.lowercased().contains("nicole teaching") {
                outputFormatter.addDebug("\nCreated pattern:")
                outputFormatter.addDebug("- Title: \(pattern.title)")
                outputFormatter.addDebug("- Day: \(pattern.dayOfWeek)")
                outputFormatter.addDebug("- Time: \(hour):\(minute)")
                outputFormatter.addDebug("- Calendar: \(pattern.calendar)")
                outputFormatter.addDebug("- Frequency: \(pattern.frequency)")
                outputFormatter.addDebug("- Score: \(pattern.score)")
            }
            
            return pattern
        }
    }
    
    func getPatternScore(for event: EventType) -> Double {
        let calendar = Calendar.current
        let title = event.title ?? ""
        
        // Debug all events
        outputFormatter.addDebug("\nScoring event:")
        outputFormatter.addDebug("- Title: \(title)")
        
        guard let startDate = event.startDate else {
            outputFormatter.addDebug("- No start date available")
            outputFormatter.addDebug("- Calendar: \(event.calendar?.title ?? "")")
            return 0.0 // Events with no date are considered novel
        }
        
        outputFormatter.addDebug("- Day: \(calendar.component(.weekday, from: startDate))")
        let timeComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        outputFormatter.addDebug("- Time: \(timeComponents.hour ?? 0):\(timeComponents.minute ?? 0)")
        outputFormatter.addDebug("- Calendar: \(event.calendar?.title ?? "")")
        
        outputFormatter.addDebug("\nMatching against patterns:")
        for pattern in patterns {
            let similar = pattern.isSimilarTo(event: event, calendar: calendar)
            outputFormatter.addDebug("\nPattern:")
            outputFormatter.addDebug("- Title: \(pattern.title) (similar: \(similar))")
            outputFormatter.addDebug("- Day: \(pattern.dayOfWeek)")
            let patternTime = calendar.dateComponents([.hour, .minute], from: pattern.timeOfDay)
            outputFormatter.addDebug("- Time: \(patternTime.hour ?? 0):\(patternTime.minute ?? 0)")
            outputFormatter.addDebug("- Calendar: \(pattern.calendar)")
            outputFormatter.addDebug("- Frequency: \(pattern.frequency)")
            outputFormatter.addDebug("- Score: \(pattern.score)")
        }
        
        // Find similar patterns and get the highest score
        let similarPatterns = patterns.filter { pattern in
            pattern.isSimilarTo(event: event, calendar: calendar)
        }
        
        if let maxScore = similarPatterns.map({ $0.score }).max() {
            outputFormatter.addDebug("\nFinal score: \(maxScore)")
            return maxScore
        }
        
        outputFormatter.addDebug("\nNo matching patterns found, score: 0.0")
        return 0.0
    }
} 