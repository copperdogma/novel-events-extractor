import XCTest
import EventKit
@testable import NovelEventsExtractor

final class CalendarManagerTests: XCTestCase {
    var mockEventStore: MockEventStore!
    var outputFormatter: OutputFormatter!
    var calendarManager: CalendarManager!
    
    override func setUp() {
        super.setUp()
        mockEventStore = MockEventStore()
        outputFormatter = OutputFormatter(isDebugEnabled: false)
        
        // Load test data
        let (calendars, events) = MockEventFactory.createTestData()
        mockEventStore.mockCalendars = calendars
        mockEventStore.mockEvents = events
        
        // Default to granting access
        mockEventStore.shouldGrantAccess = true
    }
    
    func testCalendarAccess() async throws {
        // Test successful access
        calendarManager = CalendarManager(eventStore: mockEventStore, outputFormatter: outputFormatter)
        try await calendarManager.requestAccess()
        
        // Test denied access
        mockEventStore.shouldGrantAccess = false
        calendarManager = CalendarManager(eventStore: mockEventStore, outputFormatter: outputFormatter)
        do {
            try await calendarManager.requestAccess()
            XCTFail("Expected access denied error")
        } catch CalendarError.accessDenied {
            // Expected error
        }
    }
    
    func testCalendarFiltering() async throws {
        // Test multiple blacklisted calendars
        let blacklistedCalendars = Set(["Birthdays", "Holidays"])
        calendarManager = CalendarManager(eventStore: mockEventStore,
                                        outputFormatter: outputFormatter,
                                        blacklistedCalendars: blacklistedCalendars)
        
        let historicalEvents = try await calendarManager.fetchHistoricalEvents()
        XCTAssertFalse(historicalEvents.contains { blacklistedCalendars.contains($0.calendar.title) },
                      "Events from blacklisted calendars should be excluded")
        
        // Test case sensitivity
        let mixedCaseBlacklist = Set(["birthdays", "HOLIDAYS"])
        calendarManager = CalendarManager(eventStore: mockEventStore,
                                        outputFormatter: outputFormatter,
                                        blacklistedCalendars: mixedCaseBlacklist)
        
        let caseEvents = try await calendarManager.fetchHistoricalEvents()
        XCTAssertTrue(caseEvents.contains { $0.calendar.title == "Birthdays" },
                     "Calendar filtering should be case-sensitive")
        
        // Test empty blacklist/whitelist
        calendarManager = CalendarManager(eventStore: mockEventStore,
                                        outputFormatter: outputFormatter,
                                        blacklistedCalendars: [],
                                        whitelistedCalendars: nil)
        
        let allEvents = try await calendarManager.fetchHistoricalEvents()
        XCTAssertFalse(allEvents.isEmpty, "Empty blacklist should not exclude any events")
        
        // Test whitelist
        let whitelistedCalendars = Set(["Work"])
        calendarManager = CalendarManager(eventStore: mockEventStore,
                                        outputFormatter: outputFormatter,
                                        whitelistedCalendars: whitelistedCalendars)
        
        let upcomingEvents = try await calendarManager.fetchUpcomingEvents()
        XCTAssertTrue(upcomingEvents.allSatisfy { $0.calendar.title == "Work" },
                     "Only events from whitelisted calendar should be included")
        
        // Test combined blacklist and whitelist
        calendarManager = CalendarManager(eventStore: mockEventStore,
                                        outputFormatter: outputFormatter,
                                        blacklistedCalendars: blacklistedCalendars,
                                        whitelistedCalendars: whitelistedCalendars)
        
        let events = try await calendarManager.fetchHistoricalEvents()
        XCTAssertTrue(events.allSatisfy { $0.calendar.title == "Work" },
                     "Events should be filtered by both blacklist and whitelist")
        XCTAssertFalse(events.contains { blacklistedCalendars.contains($0.calendar.title) },
                      "Blacklisted events should be excluded even if in whitelist")
        
        // Test debug output
        outputFormatter = OutputFormatter(isDebugEnabled: true)
        calendarManager = CalendarManager(eventStore: mockEventStore,
                                        outputFormatter: outputFormatter,
                                        blacklistedCalendars: blacklistedCalendars)
        
        try await calendarManager.requestAccess()
        let debugOutput = outputFormatter.getDebugOutput()
        XCTAssertTrue(debugOutput.contains("(blacklisted)"), "Debug output should indicate blacklisted calendars")
        XCTAssertTrue(debugOutput.contains("(included)"), "Debug output should indicate included calendars")
    }
    
    func testDateRanges() async throws {
        calendarManager = CalendarManager(eventStore: mockEventStore, outputFormatter: outputFormatter)
        
        // Test historical events (past year)
        let historicalEvents = try await calendarManager.fetchHistoricalEvents()
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!
        
        XCTAssertTrue(historicalEvents.allSatisfy { $0.startDate >= oneYearAgo && $0.startDate <= now },
                     "Historical events should be within the past year")
        
        // Test upcoming events (next two weeks)
        let upcomingEvents = try await calendarManager.fetchUpcomingEvents()
        let twoWeeksAhead = Calendar.current.date(byAdding: .day, value: 14, to: now)!
        
        XCTAssertTrue(upcomingEvents.allSatisfy { $0.startDate >= now && $0.startDate <= twoWeeksAhead },
                     "Upcoming events should be within the next two weeks")
    }
} 