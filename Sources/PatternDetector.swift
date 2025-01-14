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
    func isSimilarTo(event: EKEvent, calendar: Calendar) -> Bool {
        let eventTitle = event.title?.lowercased() ?? ""
        let patternTitle = title.lowercased()
        
        // Check if titles are similar (either exact match or one contains the other)
        let titleMatches = patternTitle == eventTitle || 
                         patternTitle.contains(eventTitle) || 
                         eventTitle.contains(patternTitle)
        
        // Check if times are within 1 hour of each other
        let timeComponents = calendar.dateComponents([.hour, .minute], from: event.startDate)
        let patternTime = calendar.dateComponents([.hour, .minute], from: timeOfDay)
        let hourDiff = abs((timeComponents.hour ?? 0) - (patternTime.hour ?? 0))
        
        // Consider events similar if they're in the same calendar, have similar titles,
        // and occur at similar times
        return self.calendar == event.calendar.title &&
               titleMatches &&
               hourDiff <= 1
    }
}

class PatternDetector {
    private var patterns: [EventPattern] = []
    private let outputFormatter: OutputFormatter
    
    init(outputFormatter: OutputFormatter) {
        self.outputFormatter = outputFormatter
    }
    
    func analyzeEvents(_ events: [EKEvent]) {
        var patternMap: [String: Int] = [:]
        let calendar = Calendar.current
        
        outputFormatter.addDebug("\nAnalyzing event patterns:")
        
        for event in events {
            let dayOfWeek = calendar.component(.weekday, from: event.startDate)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: event.startDate)
            let hour = timeComponents.hour ?? 0
            let minute = timeComponents.minute ?? 0
            let title = event.title ?? ""
            let calendarTitle = event.calendar.title
            
            // Create a unique key for this event pattern
            let key = "\(dayOfWeek)|\(hour):\(minute)|\(title)|\(calendarTitle)"
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
    
    func getPatternScore(for event: EKEvent) -> Double {
        let calendar = Calendar.current
        let title = event.title ?? ""
        
        // Debug scoring for Nicole teaching events
        if title.lowercased().contains("nicole teaching") {
            outputFormatter.addDebug("\nScoring teaching event:")
            outputFormatter.addDebug("- Title: \(title)")
            outputFormatter.addDebug("- Day: \(calendar.component(.weekday, from: event.startDate))")
            let timeComponents = calendar.dateComponents([.hour, .minute], from: event.startDate)
            outputFormatter.addDebug("- Time: \(timeComponents.hour ?? 0):\(timeComponents.minute ?? 0)")
            outputFormatter.addDebug("- Calendar: \(event.calendar.title)")
            
            outputFormatter.addDebug("\nMatching against patterns:")
            for pattern in patterns {
                if pattern.title.lowercased().contains("nicole teaching") {
                    let similar = pattern.isSimilarTo(event: event, calendar: calendar)
                    outputFormatter.addDebug("\nPattern:")
                    outputFormatter.addDebug("- Title: \(pattern.title) (similar: \(similar))")
                    outputFormatter.addDebug("- Day: \(pattern.dayOfWeek)")
                    let patternTime = calendar.dateComponents([.hour, .minute], from: pattern.timeOfDay)
                    outputFormatter.addDebug("- Time: \(patternTime.hour ?? 0):\(patternTime.minute ?? 0)")
                    outputFormatter.addDebug("- Calendar: \(pattern.calendar)")
                    outputFormatter.addDebug("- Score: \(pattern.score)")
                }
            }
        }
        
        // Find similar patterns and get the highest score
        let similarPatterns = patterns.filter { pattern in
            pattern.isSimilarTo(event: event, calendar: calendar)
        }
        
        if let maxScore = similarPatterns.map({ $0.score }).max() {
            if title.lowercased().contains("nicole teaching") {
                outputFormatter.addDebug("Final score: \(maxScore)")
            }
            return maxScore
        }
        
        if title.lowercased().contains("nicole teaching") {
            outputFormatter.addDebug("No matching patterns found, score: 0.0")
        }
        return 0.0
    }
} 