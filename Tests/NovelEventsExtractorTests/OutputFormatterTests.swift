import XCTest
import EventKit
@testable import NovelEventsExtractor

final class OutputFormatterTests: XCTestCase {
    var outputFormatter: OutputFormatter!
    var mockEvent: MockEvent!
    var mockCalendar: MockCalendar!
    
    override func setUp() {
        super.setUp()
        outputFormatter = OutputFormatter(isDebugEnabled: true)
        
        // Create mock calendar
        mockCalendar = MockCalendar()
        mockCalendar.title = "Test Calendar"
        mockCalendar.type = .local
        
        // Create mock event
        mockEvent = MockEvent()
        mockEvent.title = "Test Event"
        mockEvent.startDate = createDate(year: 2025, month: 1, day: 15, hour: 14, minute: 30)
        mockEvent.endDate = createDate(year: 2025, month: 1, day: 15, hour: 15, minute: 30)
        mockEvent.setCalendar(mockCalendar)
    }
    
    func testBasicFormatting() {
        let novelEvent = NovelEvent(event: mockEvent, noveltyScore: 0.0, reason: "Test")
        let output = outputFormatter.formatNovelEvents([novelEvent], lookAheadDays: 14)
        
        // Check header
        XCTAssertTrue(output.contains("Novel events found in next 14 days"), "Output should contain header")
        XCTAssertTrue(output.contains("Generated: "), "Output should contain timestamp")
        
        // Check event formatting
        XCTAssertTrue(output.contains("Jan 15 1430 Test Event [Test Calendar]"),
                     "Event should be formatted correctly")
    }
    
    func testDebugOutput() {
        // Test with debug enabled
        outputFormatter.addDebug("Debug message 1")
        outputFormatter.addDebug("Debug message 2")
        
        let output = outputFormatter.formatNovelEvents([], lookAheadDays: 14)
        XCTAssertTrue(output.contains("Debug message 1"), "Debug messages should be included when enabled")
        XCTAssertTrue(output.contains("Debug message 2"), "All debug messages should be included")
        
        // Test with debug disabled
        outputFormatter = OutputFormatter(isDebugEnabled: false)
        outputFormatter.addDebug("Debug message 3")
        
        let outputNoDebug = outputFormatter.formatNovelEvents([], lookAheadDays: 14)
        XCTAssertFalse(outputNoDebug.contains("Debug message 3"),
                      "Debug messages should not be included when disabled")
    }
    
    func testMultipleEvents() {
        // Create events at different times
        let event1 = createMockEvent(title: "Morning Event",
                                   hour: 9, minute: 0,
                                   calendar: "Calendar 1")
        let event2 = createMockEvent(title: "Afternoon Event",
                                   hour: 14, minute: 30,
                                   calendar: "Calendar 2")
        let event3 = createMockEvent(title: "Evening Event",
                                   hour: 19, minute: 45,
                                   calendar: "Calendar 1")
        
        let novelEvents = [
            NovelEvent(event: event1, noveltyScore: 0.0, reason: "Test"),
            NovelEvent(event: event2, noveltyScore: 0.0, reason: "Test"),
            NovelEvent(event: event3, noveltyScore: 0.0, reason: "Test")
        ]
        
        let output = outputFormatter.formatNovelEvents(novelEvents, lookAheadDays: 14)
        
        // Check all events are included and formatted correctly
        XCTAssertTrue(output.contains("0900 Morning Event [Calendar 1]"),
                     "Morning event should be formatted correctly")
        XCTAssertTrue(output.contains("1430 Afternoon Event [Calendar 2]"),
                     "Afternoon event should be formatted correctly")
        XCTAssertTrue(output.contains("1945 Evening Event [Calendar 1]"),
                     "Evening event should be formatted correctly")
    }
    
    func testEdgeCases() {
        // Test untitled event
        let untitledEvent = createMockEvent(title: nil,
                                          hour: 12, minute: 0,
                                          calendar: "Calendar")
        let novelEvent = NovelEvent(event: untitledEvent, noveltyScore: 0.0, reason: "Test")
        
        let output = outputFormatter.formatNovelEvents([novelEvent], lookAheadDays: 14)
        XCTAssertTrue(output.contains("Untitled Event"),
                     "Untitled events should use default title")
        
        // Test empty event list
        let emptyOutput = outputFormatter.formatNovelEvents([], lookAheadDays: 14)
        XCTAssertTrue(emptyOutput.contains("Novel events found"),
                     "Empty event list should still show header")
        
        // Test different look-ahead periods
        let shortOutput = outputFormatter.formatNovelEvents([], lookAheadDays: 7)
        XCTAssertTrue(shortOutput.contains("next 7 days"),
                     "Look-ahead period should be reflected in header")
    }
    
    func testFileWriting() throws {
        let testContent = "Test content"
        let tempFile = NSTemporaryDirectory() + "test_output.txt"
        
        // Test writing
        try outputFormatter.writeToFile(testContent, at: tempFile)
        
        // Verify content
        let readContent = try String(contentsOfFile: tempFile, encoding: .utf8)
        XCTAssertEqual(readContent, testContent, "Written content should match original")
        
        // Clean up
        try FileManager.default.removeItem(atPath: tempFile)
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
    
    private func createMockEvent(title: String?, hour: Int, minute: Int, calendar: String) -> EventType {
        let event = MockEvent()
        event.title = title
        event.startDate = createDate(year: 2025, month: 1, day: 15, hour: hour, minute: minute)
        event.endDate = createDate(year: 2025, month: 1, day: 15, hour: hour + 1, minute: minute)
        
        let cal = MockCalendar()
        cal.title = calendar
        cal.type = .local
        event.setCalendar(cal)
        
        return event
    }
} 