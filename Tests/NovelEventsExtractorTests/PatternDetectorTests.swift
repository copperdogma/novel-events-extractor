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