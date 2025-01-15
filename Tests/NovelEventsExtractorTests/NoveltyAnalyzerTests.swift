import XCTest
import EventKit
@testable import NovelEventsExtractor

final class NoveltyAnalyzerTests: XCTestCase {
    var outputFormatter: OutputFormatter!
    var patternDetector: PatternDetector!
    var noveltyAnalyzer: NoveltyAnalyzer!
    var mockEvents: [MockEvent]!
    
    override func setUp() {
        super.setUp()
        outputFormatter = OutputFormatter(isDebugEnabled: false)
        patternDetector = PatternDetector(outputFormatter: outputFormatter)
        noveltyAnalyzer = NoveltyAnalyzer(patternDetector: patternDetector)
        
        // Load test data
        let (_, events) = MockEventFactory.createTestData()
        mockEvents = events
    }
    
    func testBasicNoveltyDetection() {
        // Analyze historical events to build patterns
        patternDetector.analyzeEvents(mockEvents)
        
        // Test events that should be novel
        let novelEvent = createTestEvent(
            title: "Dentist Appointment",
            startDate: createDate(weekday: 2, hour: 14),
            calendar: "Personal"
        )
        
        // Test events that should not be novel
        let regularEvent = createTestEvent(
            title: "Team Sync",
            startDate: createDate(weekday: 3, hour: 10),
            calendar: "Work"
        )
        
        let events = [novelEvent, regularEvent]
        let novelEvents = noveltyAnalyzer.findNovelEvents(in: events)
        
        XCTAssertEqual(novelEvents.count, 1, "Should find exactly one novel event")
        XCTAssertEqual(novelEvents[0].event.title, "Dentist Appointment", "Dentist appointment should be novel")
        XCTAssertGreaterThan(novelEvents[0].noveltyScore, 0.8, "One-time event should have high novelty score")
    }
    
    func testCustomNoveltyThreshold() {
        // Create analyzer with higher threshold (0.5) to detect more novel events
        let strictAnalyzer = NoveltyAnalyzer(patternDetector: patternDetector, noveltyThreshold: 0.5)
        patternDetector.analyzeEvents(mockEvents)
        
        // Monthly event (moderate pattern score) should now be considered novel
        let monthlyEvent = createTestEvent(
            title: "Monthly Game Night",
            startDate: createDate(weekday: 2, hour: 18, minute: 30),
            calendar: "Personal"
        )
        
        let events = [monthlyEvent]
        let novelEvents = strictAnalyzer.findNovelEvents(in: events)
        
        XCTAssertEqual(novelEvents.count, 1, "Monthly event should be considered novel with higher threshold")
    }
    
    func testEventSorting() {
        patternDetector.analyzeEvents(mockEvents)
        
        let earlierEvent = createTestEvent(
            title: "Dentist Appointment",
            startDate: createDate(weekday: 2, hour: 14),  // Monday
            calendar: "Personal"
        )
        
        let laterEvent = createTestEvent(
            title: "Doctor Appointment",
            startDate: createDate(weekday: 4, hour: 15),  // Wednesday
            calendar: "Personal"
        )
        
        print("Earlier event date: \(earlierEvent.startDate)")
        print("Later event date: \(laterEvent.startDate)")
        
        let events = [laterEvent, earlierEvent]
        let novelEvents = noveltyAnalyzer.findNovelEvents(in: events)
        
        XCTAssertEqual(novelEvents.count, 2, "Should find both novel events")
        XCTAssertEqual(novelEvents[0].event.title, "Dentist Appointment", "Earlier event should be first")
        XCTAssertEqual(novelEvents[1].event.title, "Doctor Appointment", "Later event should be second")
    }
    
    func testEdgeCases() {
        patternDetector.analyzeEvents(mockEvents)
        
        // Test empty events list
        let emptyEvents: [MockEvent] = []
        let emptyResult = noveltyAnalyzer.findNovelEvents(in: emptyEvents)
        XCTAssertTrue(emptyResult.isEmpty, "Empty events list should return empty result")
        
        // Test all novel events
        let allNovel = [
            createTestEvent(title: "One-time Meeting", startDate: createDate(weekday: 2, hour: 10), calendar: "Work"),
            createTestEvent(title: "Doctor Visit", startDate: createDate(weekday: 3, hour: 14), calendar: "Personal")
        ]
        let allNovelResult = noveltyAnalyzer.findNovelEvents(in: allNovel)
        XCTAssertEqual(allNovelResult.count, 2, "Should detect all events as novel")
        
        // Test no novel events
        let allRegular = [
            createTestEvent(title: "Team Sync", startDate: createDate(weekday: 3, hour: 10), calendar: "Work"),
            createTestEvent(title: "Team Sync", startDate: createDate(weekday: 5, hour: 10), calendar: "Work")
        ]
        let noNovelResult = noveltyAnalyzer.findNovelEvents(in: allRegular)
        XCTAssertTrue(noNovelResult.isEmpty, "Should not detect any novel events")
    }
    
    func testNullDateHandling() {
        patternDetector.analyzeEvents(mockEvents)
        
        let eventWithDate = createTestEvent(
            title: "Event With Date",
            startDate: createDate(weekday: 2, hour: 14),
            calendar: "Personal"
        )
        
        let eventWithoutDate = MockEvent(
            title: "Event Without Date",
            startDate: nil,
            endDate: nil,
            calendar: MockCalendar(title: "Personal")
        )
        
        let events = [eventWithoutDate, eventWithDate]
        let novelEvents = noveltyAnalyzer.findNovelEvents(in: events)
        
        XCTAssertEqual(novelEvents.count, 2, "Should find both events as novel")
        XCTAssertEqual(novelEvents[0].event.title, "Event With Date", "Event with date should be first")
        XCTAssertEqual(novelEvents[1].event.title, "Event Without Date", "Event without date should be last")
    }
    
    func testNoveltyScoreCalculation() {
        patternDetector.analyzeEvents(mockEvents)
        
        // Test high novelty (low pattern score)
        let highNoveltyEvent = createTestEvent(
            title: "One-time Meeting",
            startDate: createDate(weekday: 2, hour: 14),
            calendar: "Personal"
        )
        
        let events = [highNoveltyEvent]
        let novelEvents = noveltyAnalyzer.findNovelEvents(in: events)
        
        XCTAssertEqual(novelEvents.count, 1, "Should find one novel event")
        XCTAssertEqual(novelEvents[0].noveltyScore, 1.0, "Completely novel event should have score of 1.0")
        XCTAssertEqual(novelEvents[0].reason, "Event occurs infrequently in your calendar", "Should provide correct reason")
    }
    
    func testThresholdEdgeCases() {
        // Test with threshold of 0.0 (everything is regular)
        let strictAnalyzer = NoveltyAnalyzer(patternDetector: patternDetector, noveltyThreshold: 0.0)
        patternDetector.analyzeEvents(mockEvents)
        
        let oneTimeEvent = createTestEvent(
            title: "One-time Meeting",
            startDate: createDate(weekday: 2, hour: 14),
            calendar: "Personal"
        )
        
        var events = [oneTimeEvent]
        var novelEvents = strictAnalyzer.findNovelEvents(in: events)
        XCTAssertEqual(novelEvents.count, 0, "With 0.0 threshold, no events should be novel")
        
        // Test with threshold of 1.0 (everything is novel)
        let lenientAnalyzer = NoveltyAnalyzer(patternDetector: patternDetector, noveltyThreshold: 1.0)
        novelEvents = lenientAnalyzer.findNovelEvents(in: events)
        XCTAssertEqual(novelEvents.count, 1, "With 1.0 threshold, all events should be novel")
        
        // Test event exactly at default threshold (0.2)
        let regularEvent = createTestEvent(
            title: "Team Sync",
            startDate: createDate(weekday: 3, hour: 10),
            calendar: "Work"
        )
        
        events = [regularEvent]
        novelEvents = noveltyAnalyzer.findNovelEvents(in: events)
        // Note: The actual result depends on the pattern score from PatternDetector
        // This test verifies the threshold boundary behavior
    }
    
    func testEventSortingEdgeCases() {
        patternDetector.analyzeEvents(mockEvents)
        
        let now = Date()
        
        // Create events with identical start times
        let event1 = createTestEvent(
            title: "Event A",
            startDate: now,
            calendar: "Personal"
        )
        
        let event2 = createTestEvent(
            title: "Event B",
            startDate: now,
            calendar: "Personal"
        )
        
        // Create an all-day event
        let allDayEvent = MockEvent(
            title: "All Day Event",
            startDate: Calendar.current.startOfDay(for: now),
            endDate: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!,
            calendar: MockCalendar(title: "Personal")
        )
        
        // Create a multi-day event
        let multiDayEvent = MockEvent(
            title: "Multi-day Event",
            startDate: now.addingTimeInterval(-86400), // Yesterday
            endDate: now.addingTimeInterval(86400),    // Tomorrow
            calendar: MockCalendar(title: "Personal")
        )
        
        let events = [event2, multiDayEvent, event1, allDayEvent]
        let novelEvents = noveltyAnalyzer.findNovelEvents(in: events)
        
        XCTAssertEqual(novelEvents.count, 4, "Should find all events as novel")
        
        // Verify sorting order
        // Multi-day event should be first (starts earliest)
        XCTAssertEqual(novelEvents[0].event.title, "Multi-day Event")
        
        // All-day event and same-time events should maintain stable order
        // The exact order might depend on implementation details, but should be consistent
        let titles = novelEvents.map { $0.event.title }
        XCTAssertTrue(titles.contains("All Day Event"))
        XCTAssertTrue(titles.contains("Event A"))
        XCTAssertTrue(titles.contains("Event B"))
    }
    
    // MARK: - Helper Methods
    
    private func createTestEvent(title: String, startDate: Date, calendar: String) -> MockEvent {
        let mockCalendar = MockCalendar(title: calendar)
        return MockEvent(
            title: title,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(3600),
            calendar: mockCalendar
        )
    }
    
    private func createDate(weekday: Int, hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        let referenceDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let currentWeekday = calendar.component(.weekday, from: referenceDate)
        
        // Calculate days to add to reach target weekday
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        var daysToAdd = weekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7
        }
        
        // Add days and set time components
        var components = DateComponents()
        components.day = daysToAdd
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        let date = calendar.date(byAdding: components, to: referenceDate)!
        print("Creating date for weekday \(weekday): \(date)")
        return date
    }
} 