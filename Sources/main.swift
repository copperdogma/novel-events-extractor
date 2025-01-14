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
    
    // Dependencies for testing
    private var _eventStore: EventStoreType?
    var eventStore: EventStoreType {
        get { _eventStore ?? EKEventStore() }
        set { _eventStore = newValue }
    }
    var outputPath: String = "novel_events.txt"
    
    // Required by ParsableCommand
    init() {}
    
    // Required by Decodable
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blacklistFile = try container.decodeIfPresent(String.self, forKey: .blacklistFile)
        blacklist = try container.decodeIfPresent(String.self, forKey: .blacklist)
        whitelistFile = try container.decodeIfPresent(String.self, forKey: .whitelistFile)
        whitelist = try container.decodeIfPresent(String.self, forKey: .whitelist)
        debug = try container.decode(Bool.self, forKey: .debug)
    }
    
    private enum CodingKeys: String, CodingKey {
        case blacklistFile
        case blacklist
        case whitelistFile
        case whitelist
        case debug
    }
    
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
        let calendarManager = CalendarManager(eventStore: eventStore,
                                           outputFormatter: outputFormatter, 
                                           blacklistedCalendars: blacklistedCalendars,
                                           whitelistedCalendars: whitelistedCalendars)
        let patternDetector = PatternDetector(outputFormatter: outputFormatter)
        let noveltyAnalyzer = NoveltyAnalyzer(patternDetector: patternDetector)
        
        // Capture values needed in the task
        let path = outputPath
        
        // Create a semaphore to wait for the async task to complete
        let semaphore = DispatchSemaphore(value: 0)
        var taskError: Error?
        
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
                try output.write(toFile: path, atomically: true, encoding: .utf8)
                print(output)
                print("\nResults written to \(path)")
                
                // Signal completion
                semaphore.signal()
            } catch {
                taskError = error
                print("Error: \(error)")
                semaphore.signal()
            }
        }
        
        // Wait for the async task to complete
        semaphore.wait()
        
        // If there was an error in the task, throw it
        if let error = taskError {
            throw error
        }
    }
}

// Only run main() when not testing
if !_isDebugAssertConfiguration() {
    NovelEventsExtractor.main()
}
