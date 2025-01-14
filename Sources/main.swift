// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import EventKit

// Run the async main function
Task {
    do {
        try await NovelEventsExtractor.run()
    } catch {
        print("Error: \(error)")
        exit(1)
    }
}

// Keep the main thread alive
RunLoop.main.run()

struct NovelEventsExtractor {
    static func run() async throws {
        // Initialize components
        let outputFormatter = OutputFormatter(isDebugEnabled: false)
        let calendarManager = CalendarManager(outputFormatter: outputFormatter)
        let patternDetector = PatternDetector(outputFormatter: outputFormatter)
        let noveltyAnalyzer = NoveltyAnalyzer(patternDetector: patternDetector)
        
        outputFormatter.addDebug("Starting Calendar Analysis...")
        
        // Request calendar access
        outputFormatter.addDebug("Requesting calendar access...")
        try await calendarManager.requestAccess()
        outputFormatter.addDebug("Calendar access granted!")
        
        // Set up date ranges
        let now = Date()
        let calendar = Calendar.current
        
        // Get historical events (1 year back)
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
        let historicalEvents = try await calendarManager.fetchEvents(from: oneYearAgo, to: now)
        outputFormatter.addDebug("Found \(historicalEvents.count) historical events")
        
        // Analyze patterns
        outputFormatter.addDebug("Analyzing patterns...")
        patternDetector.analyzeEvents(historicalEvents)
        
        // Get upcoming events (2 weeks ahead)
        let twoWeeksAhead = calendar.date(byAdding: .day, value: 14, to: now)!
        let upcomingEvents = try await calendarManager.fetchEvents(from: now, to: twoWeeksAhead)
        outputFormatter.addDebug("Found \(upcomingEvents.count) upcoming events")
        
        // Find novel events
        let novelEvents = noveltyAnalyzer.findNovelEvents(in: upcomingEvents)
        outputFormatter.addDebug("Identified \(novelEvents.count) novel events")
        
        // Format and output results
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        print(output)
        
        // Write to file
        let outputPath = "novel_events.txt"
        try outputFormatter.writeToFile(output, at: outputPath)
        print("\nResults written to: \(outputPath)")
        
        exit(0)
    }
}
