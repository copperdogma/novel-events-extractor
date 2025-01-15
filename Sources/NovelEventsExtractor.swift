import ArgumentParser
import Foundation
import EventKit

struct ValidationError: Error, CustomStringConvertible {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var description: String {
        message
    }
}

struct NovelEventsExtractor: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Extract novel events from your calendar.",
        discussion: """
            Analyzes your calendar events to identify novel or unusual events based on patterns.
            Events that don't match regular patterns are considered novel.
            """
    )
    
    @Option(name: [.customShort("d"), .long], 
            help: "Number of days to look ahead for events (default: 14)",
            transform: { value in
                guard let days = Int(value) else {
                    throw ValidationError("Days to look ahead must be a valid number")
                }
                guard days > 0 else {
                    throw ValidationError("Days to look ahead must be greater than 0")
                }
                return days
            })
    var daysToLookAhead: Int = 14
    
    @Option(name: [.customShort("B"), .long], help: "Path to file containing blacklisted calendar names")
    var blacklistFile: String?
    
    @Option(name: [.customShort("b"), .long], help: "Comma-separated list of blacklisted calendar names")
    var blacklist: String?
    
    @Option(name: [.customShort("W"), .long], help: "Path to file containing whitelisted calendar names")
    var whitelistFile: String?
    
    @Option(name: [.customShort("w"), .long], help: "Calendar names to whitelist (comma-separated)")
    var whitelist: String?
    
    @Flag(name: [.customShort("D"), .long], help: "Enable debug output")
    var debug: Bool = false
    
    // Dependencies for testing
    private var _eventStore: EventStoreType?
    var eventStore: EventStoreType {
        get { _eventStore ?? EKEventStore() }
        set { _eventStore = newValue }
    }
    var outputPath: String = "novel_events.txt"
    
    enum CodingKeys: String, CodingKey {
        case daysToLookAhead
        case blacklistFile
        case blacklist
        case whitelistFile
        case whitelist
        case debug
    }
    
    public init() {}
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let days = try container.decode(Int.self, forKey: .daysToLookAhead)
        guard days > 0 else {
            throw ValidationError("Days to look ahead must be greater than 0")
        }
        self.daysToLookAhead = days
        self.blacklistFile = try container.decodeIfPresent(String.self, forKey: .blacklistFile)
        self.blacklist = try container.decodeIfPresent(String.self, forKey: .blacklist)
        self.whitelistFile = try container.decodeIfPresent(String.self, forKey: .whitelistFile)
        self.whitelist = try container.decodeIfPresent(String.self, forKey: .whitelist)
        self.debug = try container.decodeIfPresent(Bool.self, forKey: .debug) ?? false
    }
    
    mutating func validate() throws {
        guard daysToLookAhead > 0 else {
            throw ValidationError("Days to look ahead must be greater than 0")
        }
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
        
        // Initialize components
        let outputFormatter = OutputFormatter(isDebugEnabled: debug)
        outputFormatter.addDebug("\nStarting Novel Events Extractor with debug mode enabled")
        outputFormatter.addDebug("Blacklisted calendars: \(blacklistedCalendars)")
        if let whitelist = whitelistedCalendars {
            outputFormatter.addDebug("Whitelisted calendars: \(whitelist)")
        }
        
        // Capture all values needed in the task
        let path = outputPath
        let days = daysToLookAhead
        
        let calendarManager = CalendarManager(eventStore: eventStore,
                                            outputFormatter: outputFormatter,
                                            blacklistedCalendars: blacklistedCalendars,
                                            whitelistedCalendars: whitelistedCalendars,
                                            daysToLookAhead: days)
        let patternDetector = PatternDetector(outputFormatter: outputFormatter)
        let noveltyAnalyzer = NoveltyAnalyzer(patternDetector: patternDetector)
        
        outputFormatter.addDebug("Output will be written to: \(path)")
        
        // Create a semaphore to wait for the async task to complete
        let semaphore = DispatchSemaphore(value: 0)
        var taskError: Error?
        
        // Run the analysis
        Task {
            do {
                try await Self.runAnalysis(outputFormatter: outputFormatter,
                                    calendarManager: calendarManager,
                                    patternDetector: patternDetector,
                                    noveltyAnalyzer: noveltyAnalyzer,
                                    path: path,
                                    daysToLookAhead: days)
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
    
    private static func runAnalysis(outputFormatter: OutputFormatter,
                                  calendarManager: CalendarManager,
                                  patternDetector: PatternDetector,
                                  noveltyAnalyzer: NoveltyAnalyzer,
                                  path: String,
                                  daysToLookAhead: Int) async throws {
        outputFormatter.addDebug("\nRequesting calendar access...")
        try await calendarManager.requestAccess()
        
        outputFormatter.addDebug("\nFetching historical events...")
        let historicalEvents = try await calendarManager.fetchHistoricalEvents()
        outputFormatter.addDebug("Found \(historicalEvents.count) historical events")
        
        outputFormatter.addDebug("\nAnalyzing patterns...")
        patternDetector.analyzeEvents(historicalEvents)
        
        outputFormatter.addDebug("\nFetching upcoming events...")
        let upcomingEvents = try await calendarManager.fetchUpcomingEvents()
        outputFormatter.addDebug("Found \(upcomingEvents.count) upcoming events")
        
        outputFormatter.addDebug("\nAnalyzing novelty...")
        let novelEvents = noveltyAnalyzer.findNovelEvents(in: upcomingEvents)
        outputFormatter.addDebug("Found \(novelEvents.count) novel events")
        
        // Format and write results
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: daysToLookAhead)
        try output.write(toFile: path, atomically: true, encoding: .utf8)
        outputFormatter.addDebug("\nResults written to \(path)")
    }
    
    static func parse(_ arguments: [String] = []) throws -> NovelEventsExtractor {
        return try NovelEventsExtractor.parseAsRoot(arguments) as! NovelEventsExtractor
    }
} 