import XCTest
import EventKit
@testable import NovelEventsExtractor

final class PatternDetectorTests: XCTestCase {
    var outputFormatter: OutputFormatter!
    var patternDetector: PatternDetector!
    var mockEvents: [MockEvent]!
    
    override func setUp() {
        super.setUp()
        outputFormatter = OutputFormatter(isDebugEnabled: true)
        patternDetector = PatternDetector(outputFormatter: outputFormatter)
        
        // Load test data
        let (_, events) = MockEventFactory.createTestData()
        mockEvents = events
    }
    
    func testPatternCreation() {
        // Test that patterns are created correctly from regular events
        patternDetector.analyzeEvents(mockEvents)
        
        // Team Sync occurs every Tuesday and Thursday at 10 AM
        let teamSyncScore = patternDetector.getPatternScore(for: createTestEvent(
            title: "Team Sync",
            startDate: createDate(weekday: 3, hour: 10), // Tuesday
            calendar: "Work"
        ))
        XCTAssertGreaterThan(teamSyncScore, 0.5, "Regular bi-weekly meeting should have high pattern score")
        
        // Monthly Game Night occurs once a month
        let gameNightScore = patternDetector.getPatternScore(for: createTestEvent(
            title: "Monthly Game Night",
            startDate: createDate(weekday: 2, hour: 18, minute: 30),
            calendar: "Personal"
        ))
        XCTAssertGreaterThan(gameNightScore, 0.0, "Monthly event should have moderate pattern score")
        XCTAssertLessThan(gameNightScore, teamSyncScore, "Monthly event should score lower than bi-weekly event")
    }
    
    func testPatternMatching() {
        patternDetector.analyzeEvents(mockEvents)
        
        // Test exact match
        let exactMatchScore = patternDetector.getPatternScore(for: createTestEvent(
            title: "Team Sync",
            startDate: createDate(weekday: 3, hour: 10),
            calendar: "Work"
        ))
        XCTAssertGreaterThan(exactMatchScore, 0.5, "Exact match should have high score")
        
        // Test similar title
        let similarTitleScore = patternDetector.getPatternScore(for: createTestEvent(
            title: "Team Sync Meeting",
            startDate: createDate(weekday: 3, hour: 10),
            calendar: "Work"
        ))
        XCTAssertGreaterThan(similarTitleScore, 0.5, "Similar title should still match")
        
        // Test time window
        let nearbyTimeScore = patternDetector.getPatternScore(for: createTestEvent(
            title: "Team Sync",
            startDate: createDate(weekday: 3, hour: 10, minute: 30), // 30 minutes later
            calendar: "Work"
        ))
        XCTAssertGreaterThan(nearbyTimeScore, 0.5, "Event within 1 hour should still match")
        
        // Test different calendar
        let wrongCalendarScore = patternDetector.getPatternScore(for: createTestEvent(
            title: "Team Sync",
            startDate: createDate(weekday: 3, hour: 10),
            calendar: "Personal"
        ))
        XCTAssertEqual(wrongCalendarScore, 0.0, "Event in wrong calendar should not match")
    }
    
    func testNovelEvents() {
        patternDetector.analyzeEvents(mockEvents)
        
        // Test completely new event with unique title
        let novelScore = patternDetector.getPatternScore(for: createTestEvent(
            title: "Annual Physical Checkup",
            startDate: createDate(weekday: 2, hour: 14, minute: 30),
            calendar: "Personal"
        ))
        print(outputFormatter.getDebugOutput())  // Print debug output
        XCTAssertEqual(novelScore, 0.0, "Novel event should have zero pattern score")
    }
    
    func testFrequencyBasedTitleMatching() {
        // Create low-frequency event pattern (monthly = 12 times per year)
        let lowFreqEvents = (0..<11).map { _ in
            createTestEvent(
                title: "Monthly Review",
                startDate: createDate(weekday: 2, hour: 10), // Same exact time for all events
                calendar: "Work"
            )
        }
        
        // Create high-frequency event pattern (weekly = 52 times per year)
        let highFreqEvents = (0..<52).map { _ in
            createTestEvent(
                title: "Daily Standup",
                startDate: createDate(weekday: 2, hour: 9), // Same exact time for all events
                calendar: "Work"
            )
        }
        
        patternDetector.analyzeEvents(lowFreqEvents + highFreqEvents)
        
        // Test low-frequency exact match requirement
        let lowFreqExactMatch = patternDetector.getPatternScore(for: createTestEvent(
            title: "Monthly Review",
            startDate: createDate(weekday: 2, hour: 10),
            calendar: "Work"
        ))
        XCTAssertGreaterThan(lowFreqExactMatch, 0.0, "Exact match for low-frequency event should score > 0")
        
        let lowFreqSimilarMatch = patternDetector.getPatternScore(for: createTestEvent(
            title: "Monthly Review Meeting",
            startDate: createDate(weekday: 2, hour: 10),
            calendar: "Work"
        ))
        XCTAssertEqual(lowFreqSimilarMatch, 0.0, "Similar but not exact match for low-frequency event should score 0")
        
        // Test high-frequency partial match allowance
        let highFreqExactMatch = patternDetector.getPatternScore(for: createTestEvent(
            title: "Daily Standup",
            startDate: createDate(weekday: 2, hour: 9),
            calendar: "Work"
        ))
        XCTAssertGreaterThan(highFreqExactMatch, 0.0, "Exact match for high-frequency event should score > 0")
        
        let highFreqPartialMatch = patternDetector.getPatternScore(for: createTestEvent(
            title: "Daily Standup Meeting",
            startDate: createDate(weekday: 2, hour: 9),
            calendar: "Work"
        ))
        XCTAssertGreaterThan(highFreqPartialMatch, 0.0, "Partial match for high-frequency event should score > 0")
    }
    
    func testPatternCreationEdgeCases() {
        let validEvent = createTestEvent(
            title: "Valid Event",
            startDate: Date(),
            calendar: "Work"
        )
        
        let noTitleEvent = MockEvent(
            title: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendar: MockCalendar(title: "Work")
        )
        
        let noStartDateEvent = MockEvent(
            title: "No Start Date",
            startDate: nil,
            endDate: nil,
            calendar: MockCalendar(title: "Work")
        )
        
        let noCalendarTitleEvent = MockEvent(
            title: "No Calendar",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendar: MockCalendar(title: "")
        )
        
        // Test with mix of valid and invalid events
        patternDetector.analyzeEvents([validEvent, noTitleEvent, noStartDateEvent, noCalendarTitleEvent])
        
        // Verify pattern detection still works for valid events
        let validScore = patternDetector.getPatternScore(for: validEvent)
        XCTAssertGreaterThan(validScore, 0.0, "Valid event should still be detected")
        
        // Verify invalid events are handled gracefully
        let noTitleScore = patternDetector.getPatternScore(for: noTitleEvent)
        XCTAssertEqual(noTitleScore, 0.0, "Event with no title should score 0")
        
        let noStartDateScore = patternDetector.getPatternScore(for: noStartDateEvent)
        XCTAssertEqual(noStartDateScore, 0.0, "Event with no start date should score 0")
        
        let noCalendarScore = patternDetector.getPatternScore(for: noCalendarTitleEvent)
        XCTAssertEqual(noCalendarScore, 0.0, "Event with empty calendar title should score 0")
        
        // Test empty event list
        patternDetector.analyzeEvents([])
        let emptyScore = patternDetector.getPatternScore(for: validEvent)
        XCTAssertEqual(emptyScore, 0.0, "Score should be 0 when no patterns exist")
    }
    
    func testMultiplePatternMatching() {
        // Create two similar patterns at different times
        let morningEvents = (0..<52).map { i in
            createTestEvent(
                title: "Team Sync",
                startDate: createDate(weekday: 2, hour: 9),
                calendar: "Work"
            )
        }
        
        let afternoonEvents = (0..<52).map { i in
            createTestEvent(
                title: "Team Sync",
                startDate: createDate(weekday: 2, hour: 14),
                calendar: "Work"
            )
        }
        
        patternDetector.analyzeEvents(morningEvents + afternoonEvents)
        
        // Test event matching both patterns
        let testEvent = createTestEvent(
            title: "Team Sync",
            startDate: createDate(weekday: 2, hour: 9, minute: 30),
            calendar: "Work"
        )
        
        let score = patternDetector.getPatternScore(for: testEvent)
        XCTAssertGreaterThan(score, 0.0, "Should match at least one pattern")
        XCTAssertEqual(score, 1.0, "Should return highest matching score")
    }
    
    func testTimeWindowEdgeCases() {
        let baseEvent = createTestEvent(
            title: "Regular Meeting",
            startDate: createDate(weekday: 2, hour: 10),
            calendar: "Work"
        )
        
        // Create pattern with single event
        patternDetector.analyzeEvents([baseEvent])
        
        // Test exact boundary cases
        let exactHourBefore = createTestEvent(
            title: "Regular Meeting",
            startDate: createDate(weekday: 2, hour: 9),
            calendar: "Work"
        )
        XCTAssertGreaterThan(
            patternDetector.getPatternScore(for: exactHourBefore),
            0.0,
            "Event exactly 1 hour before should match"
        )
        
        let justInsideHour = createTestEvent(
            title: "Regular Meeting",
            startDate: createDate(weekday: 2, hour: 9, minute: 1),
            calendar: "Work"
        )
        XCTAssertGreaterThan(
            patternDetector.getPatternScore(for: justInsideHour),
            0.0,
            "Event just inside 1 hour window should match"
        )
        
        let justOutsideHour = createTestEvent(
            title: "Regular Meeting",
            startDate: createDate(weekday: 2, hour: 8, minute: 59),
            calendar: "Work"
        )
        XCTAssertEqual(
            patternDetector.getPatternScore(for: justOutsideHour),
            0.0,
            "Event just outside 1 hour window should not match"
        )
    }
    
    func testCalendarEdgeCases() {
        // Create events spanning midnight
        let eveningEvent = createTestEvent(
            title: "Late Night Meeting",
            startDate: createDate(weekday: 2, hour: 23, minute: 30),
            calendar: "Work"
        )
        
        let midnightEvent = createTestEvent(
            title: "Late Night Meeting",
            startDate: createDate(weekday: 3, hour: 0, minute: 30),
            calendar: "Work"
        )
        
        patternDetector.analyzeEvents([eveningEvent])
        
        // Test that events after midnight are treated as different patterns
        let midnightScore = patternDetector.getPatternScore(for: midnightEvent)
        XCTAssertEqual(midnightScore, 0.0, "Events after midnight should be treated as different patterns")
        
        // Test month boundary
        let lastDayEvent = createTestEvent(
            title: "Month End Review",
            startDate: Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 31, hour: 10))!,
            calendar: "Work"
        )
        
        let firstDayEvent = createTestEvent(
            title: "Month End Review",
            startDate: Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 1, hour: 10))!,
            calendar: "Work"
        )
        
        patternDetector.analyzeEvents([lastDayEvent])
        
        // Test that events on different days are treated as different patterns
        let firstDayScore = patternDetector.getPatternScore(for: firstDayEvent)
        XCTAssertEqual(firstDayScore, 0.0, "Events on different days should be treated as different patterns")
    }
    
    func testDebugOutput() {
        let teachingEvent = createTestEvent(
            title: "Nicole Teaching Math",
            startDate: createDate(weekday: 2, hour: 15),
            calendar: "Work"
        )
        
        // Clear any existing debug output
        outputFormatter = OutputFormatter(isDebugEnabled: true)
        patternDetector = PatternDetector(outputFormatter: outputFormatter)
        
        // Analyze events and get pattern score to generate debug output
        patternDetector.analyzeEvents([teachingEvent])
        _ = patternDetector.getPatternScore(for: teachingEvent)
        
        let debugOutput = outputFormatter.getDebugOutput()
        
        // Verify debug output contains expected information
        XCTAssertTrue(debugOutput.contains("Nicole Teaching Math"), "Debug output should contain event title")
        XCTAssertTrue(debugOutput.contains("Found teaching event:"), "Debug output should contain teaching event marker")
        XCTAssertTrue(debugOutput.contains("Created pattern:"), "Debug output should contain pattern creation info")
        XCTAssertTrue(debugOutput.contains("Scoring event:"), "Debug output should contain scoring info")
    }
    
    func testTitleLengthEdgeCases() {
        // Create a pattern with a long title
        let longTitleEvent = createTestEvent(
            title: "Very Long Meeting Title",
            startDate: createDate(weekday: 2, hour: 10),
            calendar: "Work"
        )
        
        // Create 52 events to make it high-frequency
        let events = (0..<52).map { _ in longTitleEvent }
        patternDetector.analyzeEvents(events)
        
        // Test short title (less than 5 chars)
        let shortTitleTest = createTestEvent(
            title: "Meet",
            startDate: createDate(weekday: 2, hour: 10),
            calendar: "Work"
        )
        let shortTitleScore = patternDetector.getPatternScore(for: shortTitleTest)
        XCTAssertEqual(shortTitleScore, 0.0, "Short titles (<5 chars) should not match partially")
        
        // Test exactly 5 chars
        let fiveCharTest = createTestEvent(
            title: "Title",
            startDate: createDate(weekday: 2, hour: 10),
            calendar: "Work"
        )
        let fiveCharScore = patternDetector.getPatternScore(for: fiveCharTest)
        XCTAssertEqual(fiveCharScore, 0.0, "Exactly 5 chars should not match partially")
        
        // Test longer title that's contained within pattern title
        let containedTitleTest = createTestEvent(
            title: "Meeting Title",
            startDate: createDate(weekday: 2, hour: 10),
            calendar: "Work"
        )
        let containedTitleScore = patternDetector.getPatternScore(for: containedTitleTest)
        XCTAssertGreaterThan(containedTitleScore, 0.0, "Title contained within pattern should match if >5 chars")
        
        // Test longer title that contains pattern title
        let containingTitleTest = createTestEvent(
            title: "Extended Very Long Meeting Title Extra",
            startDate: createDate(weekday: 2, hour: 10),
            calendar: "Work"
        )
        let containingTitleScore = patternDetector.getPatternScore(for: containingTitleTest)
        XCTAssertGreaterThan(containingTitleScore, 0.0, "Title containing pattern should match if pattern >5 chars")
    }
    
    func testFrequencyThresholds() {
        // Test exactly at the monthly threshold (12 events)
        let exactlyTwelveEvents = (0..<12).map { _ in 
            createTestEvent(
                title: "Monthly Meeting",
                startDate: createDate(weekday: 2, hour: 10),
                calendar: "Work"
            )
        }
        
        patternDetector.analyzeEvents(exactlyTwelveEvents)
        
        // Test similar title with exactly 12 frequency
        let similarTitleTest = createTestEvent(
            title: "Monthly Meeting Discussion",
            startDate: createDate(weekday: 2, hour: 10),
            calendar: "Work"
        )
        let thresholdScore = patternDetector.getPatternScore(for: similarTitleTest)
        XCTAssertGreaterThan(thresholdScore, 0.0, "Events at frequency threshold should allow partial matches")
        
        // Test just below threshold (11 events)
        patternDetector.analyzeEvents(exactlyTwelveEvents.dropLast())
        let belowThresholdScore = patternDetector.getPatternScore(for: similarTitleTest)
        XCTAssertEqual(belowThresholdScore, 0.0, "Events below frequency threshold should require exact matches")
    }
    
    func testMinuteBasedTimeDifferences() {
        let baseEvent = createTestEvent(
            title: "Regular Meeting",
            startDate: createDate(weekday: 2, hour: 10, minute: 0),
            calendar: "Work"
        )
        
        patternDetector.analyzeEvents([baseEvent])
        
        // Test various minute differences within the same hour
        let sameHourDifferentMinutes = [15, 30, 45].map { minutes in
            createTestEvent(
                title: "Regular Meeting",
                startDate: createDate(weekday: 2, hour: 10, minute: minutes),
                calendar: "Work"
            )
        }
        
        for event in sameHourDifferentMinutes {
            let score = patternDetector.getPatternScore(for: event)
            XCTAssertGreaterThan(score, 0.0, "Events in same hour should match regardless of minutes")
        }
        
        // Test minute differences that cross the hour boundary
        let crossHourEvents = [
            createTestEvent(
                title: "Regular Meeting",
                startDate: createDate(weekday: 2, hour: 9, minute: 31),
                calendar: "Work"
            ),
            createTestEvent(
                title: "Regular Meeting",
                startDate: createDate(weekday: 2, hour: 10, minute: 29),
                calendar: "Work"
            )
        ]
        
        for event in crossHourEvents {
            let score = patternDetector.getPatternScore(for: event)
            XCTAssertGreaterThan(score, 0.0, "Events within 1 hour should match even across hour boundaries")
        }
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
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        components.hour = hour
        components.minute = minute
        
        // Adjust the date to the next occurrence of the specified weekday
        let currentWeekday = calendar.component(.weekday, from: Date())
        let daysToAdd = (weekday - currentWeekday + 7) % 7
        let date = calendar.date(byAdding: .day, value: daysToAdd, to: Date())!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
    }
} 