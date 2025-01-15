import EventKit
import Foundation

class PatternDetector {
    private var patterns: [EventPattern] = []
    private let outputFormatter: OutputFormatter
    
    init(outputFormatter: OutputFormatter) {
        self.outputFormatter = outputFormatter
    }
    
    private func createPatternKey(title: String, dayOfWeek: Int, hour: Int, minute: Int, calendarTitle: String) -> String {
        // For teaching events, ignore the day of week to group them together regardless of day
        if title.lowercased().contains("teaching") {
            return "teaching|\(hour):\(minute)|\(title)|\(calendarTitle)"
        }
        return "regular|\(dayOfWeek)|\(hour):\(minute)|\(title)|\(calendarTitle)"
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
            let hour = calendar.component(.hour, from: startDate)
            let minute = calendar.component(.minute, from: startDate)
            
            // Check if it's a teaching event
            if title.lowercased().contains("teaching") {
                outputFormatter.addDebug("\nFound teaching event: \(title)")
            }
            
            let key = createPatternKey(title: title,
                                     dayOfWeek: dayOfWeek,
                                     hour: hour,
                                     minute: minute,
                                     calendarTitle: calendarTitle)
            
            patternMap[key, default: 0] += 1
            outputFormatter.addDebug("Created pattern: \(key) (count: \(patternMap[key]!))")
        }
        
        // Convert patterns to objects
        patterns = patternMap.compactMap { key, count in
            let components = key.split(separator: "|")
            guard components.count >= 4 else { return nil }  // Need at least type|time|title|calendar
            
            let patternType = components[0]
            let title = String(components[components.count - 2])
            let calendarTitle = String(components[components.count - 1])
            
            // Parse time components
            let timeComponents = components[patternType == "teaching" ? 1 : 2].split(separator: ":")
            guard timeComponents.count == 2,
                  let hour = Int(timeComponents[0]),
                  let minute = Int(timeComponents[1]) else {
                return nil
            }
            
            // Parse day of week if it's a regular event
            let dayOfWeek: Int?
            if patternType == "regular",
               let day = Int(components[1]) {
                dayOfWeek = day
            } else {
                dayOfWeek = nil
            }
            
            return EventPattern(title: title,
                              dayOfWeek: dayOfWeek,
                              hour: hour,
                              minute: minute,
                              calendarTitle: calendarTitle,
                              frequency: count)
        }
        
        outputFormatter.addDebug("\nCreated \(patterns.count) patterns:")
        for pattern in patterns {
            outputFormatter.addDebug("- \(pattern.title) (\(pattern.frequency) occurrences)")
        }
    }
    
    func getPatternScore(for event: EventType) -> Double {
        guard let title = event.title,
              let startDate = event.startDate,
              let calendarTitle = event.calendar?.title else {
            outputFormatter.addDebug("\nSkipping event: missing required properties")
            return 0.0
        }
        
        outputFormatter.addDebug("\nScoring event: \(title)")
        outputFormatter.addDebug("Calendar: \(calendarTitle)")
        outputFormatter.addDebug("Start date: \(startDate)")
        
        let similarPatterns = patterns.filter { pattern in
            pattern.isSimilarTo(event: event, calendar: Calendar.current)
        }
        
        if similarPatterns.isEmpty {
            outputFormatter.addDebug("No matching patterns found")
            return 0.0
        }
        
        outputFormatter.addDebug("\nMatching patterns:")
        for pattern in similarPatterns {
            outputFormatter.addDebug("- \(pattern.title) (frequency: \(pattern.frequency), score: \(pattern.score))")
        }
        
        if let maxScore = similarPatterns.map({ $0.score }).max() {
            outputFormatter.addDebug("Final score: \(maxScore)")
            return maxScore
        }
        
        outputFormatter.addDebug("No matching patterns found, score: 0.0")
        return 0.0
    }
} 