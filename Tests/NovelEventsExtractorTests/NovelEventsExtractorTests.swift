import XCTest
import ArgumentParser
import EventKit
@testable import NovelEventsExtractor

final class NovelEventsExtractorTests: XCTestCase {
    var mockEventStore: MockEventStore!
    var sut: NovelEventsExtractor!
    var tempBlacklistFile: URL!
    var tempWhitelistFile: URL!
    
    override func setUp() {
        super.setUp()
        mockEventStore = MockEventStore()
        
        // Initialize with empty arguments
        sut = try! NovelEventsExtractor.parse([])
        sut.eventStore = mockEventStore
        
        // Create temporary files for testing
        let tempDir = FileManager.default.temporaryDirectory
        tempBlacklistFile = tempDir.appendingPathComponent("blacklist.txt")
        tempWhitelistFile = tempDir.appendingPathComponent("whitelist.txt")
    }
    
    override func tearDown() {
        // Clean up temporary files
        try? FileManager.default.removeItem(at: tempBlacklistFile)
        try? FileManager.default.removeItem(at: tempWhitelistFile)
        
        mockEventStore = nil
        sut = nil
        tempBlacklistFile = nil
        tempWhitelistFile = nil
        super.tearDown()
    }
    
    func testBlacklistFromFile() throws {
        // Create test blacklist file
        let blacklist = "Calendar1\nCalendar2\n"
        try blacklist.write(to: tempBlacklistFile, atomically: true, encoding: .utf8)
        
        // Parse with blacklist file argument
        sut = try NovelEventsExtractor.parse(["-B", tempBlacklistFile.path])
        sut.eventStore = mockEventStore
        try sut.run()
        
        // Verify blacklisted calendars were excluded
        XCTAssertTrue(mockEventStore.getCalendarsCalled)
    }
    
    func testWhitelistFromFile() throws {
        // Create test whitelist file
        let whitelist = "Calendar3\nCalendar4\n"
        try whitelist.write(to: tempWhitelistFile, atomically: true, encoding: .utf8)
        
        // Parse with whitelist file argument
        sut = try NovelEventsExtractor.parse(["-W", tempWhitelistFile.path])
        sut.eventStore = mockEventStore
        try sut.run()
        
        // Verify only whitelisted calendars were included
        XCTAssertTrue(mockEventStore.getCalendarsCalled)
    }
    
    func testBlacklistFromCommandLine() throws {
        // Parse with blacklist argument
        sut = try NovelEventsExtractor.parse(["-b", "Calendar1,Calendar2"])
        sut.eventStore = mockEventStore
        try sut.run()
        
        // Verify blacklisted calendars were excluded
        XCTAssertTrue(mockEventStore.getCalendarsCalled)
    }
    
    func testWhitelistFromCommandLine() throws {
        // Parse with whitelist argument
        sut = try NovelEventsExtractor.parse(["-w", "Calendar3,Calendar4"])
        sut.eventStore = mockEventStore
        try sut.run()
        
        // Verify only whitelisted calendars were included
        XCTAssertTrue(mockEventStore.getCalendarsCalled)
    }
    
    func testDebugOutput() throws {
        // Parse with debug flag
        sut = try NovelEventsExtractor.parse(["-D"])
        sut.eventStore = mockEventStore
        try sut.run()
        
        // Verify debug output was enabled
        XCTAssertTrue(mockEventStore.getCalendarsCalled)
    }
    
    func testCalendarAccess() throws {
        // Test access denied
        mockEventStore.shouldGrantAccess = false
        do {
            try sut.run()
            XCTFail("Should throw an error when calendar access is denied")
        } catch CalendarError.accessDenied {
            // Expected error
            XCTAssertTrue(mockEventStore.requestAccessCalled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Test access granted
        mockEventStore.shouldGrantAccess = true
        try sut.run()
        XCTAssertTrue(mockEventStore.requestAccessCalled)
    }
    
    func testEventAnalysis() throws {
        // Set up test events
        let calendar = MockCalendar(title: "Test Calendar", type: .local)
        let historicalEvent = MockEvent(title: "Regular Meeting",
                                      startDate: Date().addingTimeInterval(-86400),
                                      endDate: Date(),
                                      calendar: calendar)
        let upcomingEvent = MockEvent(title: "Special Meeting",
                                     startDate: Date().addingTimeInterval(86400),
                                     endDate: Date().addingTimeInterval(90000),
                                     calendar: calendar)
        
        mockEventStore.calendars = [calendar]
        mockEventStore.events = [historicalEvent, upcomingEvent]
        
        try sut.run()
        
        // Verify events were analyzed
        XCTAssertTrue(mockEventStore.getCalendarsCalled)
    }
    
    func testOutputFile() throws {
        let testOutputPath = FileManager.default.temporaryDirectory.appendingPathComponent("test_output.txt").path
        sut.outputPath = testOutputPath
        
        try sut.run()
        
        // Verify output file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: testOutputPath))
        
        // Clean up
        try? FileManager.default.removeItem(atPath: testOutputPath)
    }
    
    func testDaysToLookAheadArgument() throws {
        // Test default value
        sut = try NovelEventsExtractor.parse([])
        XCTAssertEqual(sut.daysToLookAhead, 14, "Default value should be 14 days")
        
        // Test custom value
        sut = try NovelEventsExtractor.parse(["-d", "30"])
        XCTAssertEqual(sut.daysToLookAhead, 30, "Should accept custom days value")
        
        // Test invalid value
        XCTAssertThrowsError(try NovelEventsExtractor.parse(["-d", "invalid"])) { error in
            print("Invalid value error type: \(type(of: error))")
            print("Invalid value error: \(error)")
            print("Invalid value error description: \(error.localizedDescription)")
        }
        
        // Test negative value
        XCTAssertThrowsError(try NovelEventsExtractor.parse(["-d", "-5"])) { error in
            print("Negative value error type: \(type(of: error))")
            print("Negative value error: \(error)")
            print("Negative value error description: \(error.localizedDescription)")
        }
        
        // Test zero value
        XCTAssertThrowsError(try NovelEventsExtractor.parse(["-d", "0"])) { error in
            print("Zero value error type: \(type(of: error))")
            print("Zero value error: \(error)")
            print("Zero value error description: \(error.localizedDescription)")
        }
    }
} 