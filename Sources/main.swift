// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import EventKit
import ArgumentParser

struct NovelEventsExtractor: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "novel-events-extractor",
        abstract: "Analyzes calendar events to identify novel or unusual events.",
        discussion: """
            Analyzes your calendar events to identify novel or unusual events in the upcoming two weeks.
            Uses pattern recognition to learn your regular schedule and highlights events that deviate from your normal patterns.
            """
    )
    
    @Option(name: .long, help: "Path to a file containing calendar names to blacklist, one per line")
    var blacklistFile: String?
    
    @Option(name: .long, help: "Comma-separated list of calendar names to blacklist")
    var blacklist: String?
    
    @Option(name: .long, help: "Path to a file containing calendar names to whitelist, one per line")
    var whitelistFile: String?
    
    @Option(name: .long, help: "Comma-separated list of calendar names to whitelist")
    var whitelist: String?
    
    @Flag(name: .long, help: "Enable debug output")
    var debug: Bool = false
    
    mutating func run() throws {
        // Parse blacklist/whitelist options
        var blacklistedCalendars: Set<String> = []
        var whitelistedCalendars: Set<String>?
        
        if let blacklistFile = blacklistFile {
            let fileContents = try String(contentsOfFile: blacklistFile, encoding: .utf8)
            blacklistedCalendars.formUnion(fileContents.components(separatedBy: .newlines).filter { !$0.isEmpty })
        }
        
        if let blacklist = blacklist {
            blacklistedCalendars.formUnion(blacklist.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        }
        
        if let whitelistFile = whitelistFile {
            let fileContents = try String(contentsOfFile: whitelistFile, encoding: .utf8)
            let calendars = fileContents.components(separatedBy: .newlines).filter { !$0.isEmpty }
            whitelistedCalendars = Set(calendars)
        }
        
        if let whitelist = whitelist {
            let calendars = whitelist.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if whitelistedCalendars == nil {
                whitelistedCalendars = Set(calendars)
            } else {
                whitelistedCalendars?.formUnion(calendars)
            }
        }
        
        // Initialize components with the parsed options
        let outputFormatter = OutputFormatter(isDebugEnabled: debug)
        let calendarManager = CalendarManager(outputFormatter: outputFormatter, 
                                            blacklistedCalendars: blacklistedCalendars,
                                            whitelistedCalendars: whitelistedCalendars)
        let patternDetector = PatternDetector(outputFormatter: outputFormatter)
        let noveltyAnalyzer = NoveltyAnalyzer(patternDetector: patternDetector)
        
        // Create a semaphore to wait for the async task to complete
        let semaphore = DispatchSemaphore(value: 0)
        
        // Run the analysis
        Task {
            do {
                try await calendarManager.requestAccess()
                let historicalEvents = try await calendarManager.fetchHistoricalEvents()
                let upcomingEvents = try await calendarManager.fetchUpcomingEvents()
                
                patternDetector.analyzeEvents(historicalEvents)
                let novelEvents = noveltyAnalyzer.findNovelEvents(in: upcomingEvents)
                
                // Format and write results
                let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
                try output.write(toFile: "novel_events.txt", atomically: true, encoding: .utf8)
                print(output)
                print("\nResults written to novel_events.txt")
                
                // Signal completion
                semaphore.signal()
            } catch {
                print("Error: \(error)")
                semaphore.signal()
                throw error
            }
        }
        
        // Wait for the async task to complete
        semaphore.wait()
    }
}

NovelEventsExtractor.main()
