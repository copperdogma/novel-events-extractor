import XCTest
import EventKit
@testable import NovelEventsExtractor

final class OutputFormatterTests: XCTestCase {
    var outputFormatter: OutputFormatter!
    var mockEvent: MockEvent!
    var mockCalendar: MockCalendar!
    
    override func setUp() {
        super.setUp()
        outputFormatter = OutputFormatter(isDebugEnabled: false)
        
        // Create mock calendar
        mockCalendar = MockCalendar(title: "Test Calendar", type: .local)
        
        // Create mock event
        mockEvent = MockEvent(title: "Test Event",
                            startDate: createDate(year: 2025, month: 1, day: 15, hour: 10, minute: 0),
                            endDate: createDate(year: 2025, month: 1, day: 15, hour: 11, minute: 0),
                            calendar: mockCalendar)
    }
    
    override func tearDown() {
        outputFormatter = nil
        mockEvent = nil
        mockCalendar = nil
        super.tearDown()
    }
    
    func testFormatNovelEvents() {
        let novelEvents = [NovelEvent(event: mockEvent, noveltyScore: 0.8, reason: "Test reason")]
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        print("\nActual output for testFormatNovelEvents:")
        print(output)
        
        XCTAssertTrue(output.contains("Novel events found in next 14 days:"), "Missing header")
        XCTAssertTrue(output.contains("Jan 15 1000 Test Event [Test Calendar]"), "Missing event details")
        if outputFormatter.isDebugEnabled {
            XCTAssertTrue(output.contains("Test reason"), "Missing novelty reason")
        }
    }
    
    func testFormatNovelEventsEmpty() {
        let novelEvents: [NovelEvent] = []
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        XCTAssertTrue(output.contains("Novel events found in next 14 days:"), "Missing header")
        XCTAssertTrue(output.isEmpty || output.contains("No events found"), "Missing empty state message")
    }
    
    func testDebugOutput() {
        outputFormatter = OutputFormatter(isDebugEnabled: true)
        outputFormatter.addDebug("Test debug message")
        
        let debugOutput = outputFormatter.getDebugOutput()
        XCTAssertTrue(debugOutput.contains("Test debug message"))
    }
    
    func testFormatAllDayEvent() {
        // Create a date at midnight for an all-day event
        let startDate = Calendar.current.startOfDay(for: createDate(year: 2025, month: 1, day: 15, hour: 0, minute: 0))
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
        
        mockEvent = MockEvent(title: "All Day Event",
                            startDate: startDate,
                            endDate: endDate,
                            calendar: mockCalendar)
        
        let novelEvents = [NovelEvent(event: mockEvent, noveltyScore: 0.8, reason: "Test reason")]
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        XCTAssertTrue(output.contains("Jan 15 (All Day) All Day Event"), "Missing all-day event indicator")
    }
    
    func testFormatMultiDayEvent() {
        let startDate = createDate(year: 2025, month: 1, day: 15, hour: 10, minute: 0)
        let endDate = createDate(year: 2025, month: 1, day: 17, hour: 16, minute: 0)
        
        mockEvent = MockEvent(title: "Multi-day Conference",
                            startDate: startDate,
                            endDate: endDate,
                            calendar: mockCalendar)
        
        let novelEvents = [NovelEvent(event: mockEvent, noveltyScore: 0.8, reason: "Test reason")]
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        print("\nActual output for testFormatMultiDayEvent:")
        print(output)
        
        XCTAssertTrue(output.contains("Jan 15 1000 - Jan 17 1600"), "Missing multi-day event time range")
    }
    
    func testFormatSpecialCharactersAndLongTitle() {
        let longTitle = "Very Long Event Title That Exceeds Normal Length With Special Characters: @#$%^&*()_+"
        mockEvent = MockEvent(title: longTitle,
                            startDate: createDate(year: 2025, month: 1, day: 15, hour: 10, minute: 0),
                            endDate: createDate(year: 2025, month: 1, day: 15, hour: 11, minute: 0),
                            calendar: mockCalendar)
        
        let novelEvents = [NovelEvent(event: mockEvent, noveltyScore: 0.8, reason: "Test reason")]
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        XCTAssertTrue(output.contains(longTitle), "Special characters or long title not handled correctly")
    }
    
    func testMultipleDebugMessages() {
        outputFormatter = OutputFormatter(isDebugEnabled: true)
        outputFormatter.addDebug("First debug message")
        outputFormatter.addDebug("Second debug message")
        outputFormatter.addDebug("Third debug message")
        
        let debugOutput = outputFormatter.getDebugOutput()
        XCTAssertTrue(debugOutput.contains("First debug message"))
        XCTAssertTrue(debugOutput.contains("Second debug message"))
        XCTAssertTrue(debugOutput.contains("Third debug message"))
        XCTAssertTrue(debugOutput.components(separatedBy: .newlines).count >= 3, "Debug messages should be on separate lines")
    }
    
    func testDifferentNoveltyScores() {
        outputFormatter = OutputFormatter(isDebugEnabled: true)
        let events = [
            NovelEvent(event: mockEvent, noveltyScore: 1.0, reason: "Perfect novelty"),
            NovelEvent(event: mockEvent, noveltyScore: 0.5, reason: "Medium novelty"),
            NovelEvent(event: mockEvent, noveltyScore: 0.1, reason: "Low novelty")
        ]
        
        let output = outputFormatter.formatNovelEvents(events, lookAheadDays: 14)
        XCTAssertTrue(output.contains("Perfect novelty"))
        XCTAssertTrue(output.contains("Medium novelty"))
        XCTAssertTrue(output.contains("Low novelty"))
    }
    
    func testEventWithMissingProperties() {
        mockEvent = MockEvent(title: "",  // Empty title
                            startDate: createDate(year: 2025, month: 1, day: 15, hour: 10, minute: 0),
                            endDate: createDate(year: 2025, month: 1, day: 15, hour: 11, minute: 0),
                            calendar: mockCalendar)
        
        let novelEvents = [NovelEvent(event: mockEvent, noveltyScore: 0.8, reason: "Test reason")]
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        XCTAssertTrue(output.contains("[Untitled Event]") || output.contains("(No Title)"), "Missing handling for empty title")
    }
    
    func testDebugOutputWhenDisabled() {
        outputFormatter = OutputFormatter(isDebugEnabled: false)
        outputFormatter.addDebug("This should not appear")
        
        let debugOutput = outputFormatter.getDebugOutput()
        XCTAssertTrue(debugOutput.isEmpty, "Debug output should be empty when debug mode is disabled")
    }
    
    func testWriteToFile() throws {
        let testPath = FileManager.default.temporaryDirectory.appendingPathComponent("test_output.txt").path
        let testContent = "Test content"
        
        try outputFormatter.writeToFile(testContent, at: testPath)
        
        // Verify file exists and content matches
        let fileContent = try String(contentsOfFile: testPath, encoding: .utf8)
        XCTAssertEqual(fileContent, testContent)
        
        // Clean up
        try FileManager.default.removeItem(atPath: testPath)
    }
    
    func testTimestampFormat() {
        let novelEvents = [NovelEvent(event: mockEvent, noveltyScore: 0.8, reason: "Test reason")]
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        // Check timestamp format: yyyy-MM-dd HH:mm:ss zzz
        let timestampPattern = #"Generated: \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [A-Z]{3,4}"#
        XCTAssertTrue(output.range(of: timestampPattern, options: .regularExpression) != nil, "Timestamp format is incorrect")
    }
    
    func testEventWithNilDates() {
        mockEvent = MockEvent(title: "Event With Nil Dates",
                            startDate: nil,
                            endDate: nil,
                            calendar: mockCalendar)
        
        let novelEvents = [NovelEvent(event: mockEvent, noveltyScore: 0.8, reason: "Test reason")]
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        // The formatter should handle nil dates gracefully without crashing
        XCTAssertTrue(output.contains("Event With Nil Dates"), "Event with nil dates not handled correctly")
    }
    
    func testMultiDayAllDayEvent() {
        let startDate = Calendar.current.startOfDay(for: createDate(year: 2025, month: 1, day: 15, hour: 0, minute: 0))
        let endDate = Calendar.current.date(byAdding: .day, value: 3, to: startDate)! // 3-day event
        
        mockEvent = MockEvent(title: "Three Day Conference",
                            startDate: startDate,
                            endDate: endDate,
                            calendar: mockCalendar)
        
        let novelEvents = [NovelEvent(event: mockEvent, noveltyScore: 0.8, reason: "Test reason")]
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        XCTAssertTrue(output.contains("Jan 15 (All Day) - Jan 17 (All Day)"), "Multi-day all-day event not formatted correctly")
    }
    
    func testTimezoneHandling() {
        // Test with a specific timezone
        let nyTimezone = TimeZone(identifier: "America/New_York")!
        
        // Create a fixed date in NY timezone
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 10
        components.minute = 0
        components.timeZone = nyTimezone
        
        let fixedDate = Calendar.current.date(from: components)!
        
        // Create mock event with the fixed date
        mockEvent = MockEvent(title: "Test Event",
                            startDate: fixedDate,
                            endDate: fixedDate.addingTimeInterval(3600),
                            calendar: mockCalendar)
        
        // Create formatter with NY timezone
        outputFormatter = OutputFormatter(isDebugEnabled: false)
        outputFormatter.setTimeZone(nyTimezone)
        
        let novelEvents = [NovelEvent(event: mockEvent, noveltyScore: 0.8, reason: "Test reason")]
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        print("\nActual output for testTimezoneHandling:")
        print(output)
        
        // Verify the timestamp includes EST/EDT
        XCTAssertTrue(output.contains("EST") || output.contains("EDT"), "Timezone not included in timestamp")
    }
    
    func testEventSorting() {
        let event1 = MockEvent(title: "Later Event",
                             startDate: createDate(year: 2025, month: 1, day: 16, hour: 10, minute: 0),
                             endDate: createDate(year: 2025, month: 1, day: 16, hour: 11, minute: 0),
                             calendar: mockCalendar)
        
        let event2 = MockEvent(title: "Earlier Event",
                             startDate: createDate(year: 2025, month: 1, day: 15, hour: 10, minute: 0),
                             endDate: createDate(year: 2025, month: 1, day: 15, hour: 11, minute: 0),
                             calendar: mockCalendar)
        
        let novelEvents = [
            NovelEvent(event: event1, noveltyScore: 0.8, reason: "Test reason 1"),
            NovelEvent(event: event2, noveltyScore: 0.8, reason: "Test reason 2")
        ]
        
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        // Find indices of both events in the output
        let event1Index = output.range(of: "Later Event")?.lowerBound
        let event2Index = output.range(of: "Earlier Event")?.lowerBound
        
        XCTAssertNotNil(event1Index)
        XCTAssertNotNil(event2Index)
        XCTAssertLessThan(event2Index!, event1Index!, "Events should be sorted chronologically")
    }
    
    func testCalendarWithDifferentTimezone() {
        // Set formatter to NY timezone
        let nyTimezone = TimeZone(identifier: "America/New_York")!
        outputFormatter.setTimeZone(nyTimezone)
        
        // Create event in LA timezone
        let laTimezone = TimeZone(identifier: "America/Los_Angeles")!
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 10  // 10 AM LA time = 1 PM NY time
        components.minute = 0
        components.timeZone = laTimezone
        
        let laDate = Calendar.current.date(from: components)!
        mockEvent = MockEvent(title: "West Coast Meeting",
                            startDate: laDate,
                            endDate: laDate.addingTimeInterval(3600),
                            calendar: mockCalendar)
        
        let novelEvents = [NovelEvent(event: mockEvent, noveltyScore: 0.8, reason: "Test reason")]
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        XCTAssertTrue(output.contains("Jan 15 1300"), "Event time should be converted to NY timezone")
    }
    
    func testEventSpanningDST() {
        // Create a date that spans across DST change
        // 2025 DST begins on March 9 at 2 AM
        let nyTimezone = TimeZone(identifier: "America/New_York")!
        outputFormatter.setTimeZone(nyTimezone)
        
        var components = DateComponents()
        components.year = 2025
        components.month = 3
        components.day = 9
        components.hour = 1  // 1 AM before DST change
        components.minute = 0
        components.timeZone = nyTimezone
        
        let startDate = Calendar.current.date(from: components)!
        
        // Create end date on next day to ensure we show both times
        components.day = 10
        components.hour = 13  // 1 PM next day
        let endDate = Calendar.current.date(from: components)!
        
        mockEvent = MockEvent(title: "DST Spanning Event",
                            startDate: startDate,
                            endDate: endDate,
                            calendar: mockCalendar)
        
        let novelEvents = [NovelEvent(event: mockEvent, noveltyScore: 0.8, reason: "Test reason")]
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        print("\nActual output for testEventSpanningDST:")
        print(output)
        
        XCTAssertTrue(output.contains("Mar 09 0100 - Mar 10 1300"), "Should show correct times across DST change")
    }
    
    func testEventWithNegativeDuration() {
        // Create an event where end date is before start date
        let startDate = createDate(year: 2025, month: 1, day: 15, hour: 10, minute: 0)
        let endDate = startDate.addingTimeInterval(-3600) // End date 1 hour before start
        
        mockEvent = MockEvent(title: "Negative Duration Event",
                            startDate: startDate,
                            endDate: endDate,
                            calendar: mockCalendar)
        
        let novelEvents = [NovelEvent(event: mockEvent, noveltyScore: 0.8, reason: "Test reason")]
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        // The formatter should handle this gracefully by just showing the start time
        XCTAssertTrue(output.contains("Jan 15 1000"), "Should show start time despite negative duration")
        XCTAssertTrue(output.contains("Negative Duration Event"), "Event title should be included")
    }
    
    // MARK: - Helper Methods
    
    private func createDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        
        return Calendar.current.date(from: components)!
    }
} 