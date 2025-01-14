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
        
        XCTAssertTrue(output.contains("Novel events found in next 14 days:"), "Missing header")
        XCTAssertTrue(output.contains("Jan 15 1000 Test Event [Test Calendar]"), "Missing event details")
        XCTAssertTrue(output.contains("Test reason"), "Missing novelty reason")
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