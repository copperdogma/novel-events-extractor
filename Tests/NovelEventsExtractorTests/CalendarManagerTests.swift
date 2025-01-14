import XCTest
@testable import NovelEventsExtractor

final class CalendarManagerTests: XCTestCase {
    var mockEventStore: MockEventStore!
    var outputFormatter: OutputFormatter!
    var sut: CalendarManager!
    
    override func setUp() {
        super.setUp()
        mockEventStore = MockEventStore()
        outputFormatter = OutputFormatter(isDebugEnabled: false)
        sut = CalendarManager(eventStore: mockEventStore,
                            outputFormatter: outputFormatter)
    }
    
    override func tearDown() {
        mockEventStore = nil
        outputFormatter = nil
        sut = nil
        super.tearDown()
    }
    
    func testRequestAccessSuccess() async throws {
        mockEventStore.shouldGrantAccess = true
        try await sut.requestAccess()
        XCTAssertTrue(mockEventStore.requestAccessCalled)
    }
    
    func testRequestAccessFailure() async {
        mockEventStore.shouldGrantAccess = false
        do {
            try await sut.requestAccess()
            XCTFail("Expected requestAccess to throw")
        } catch {
            XCTAssertTrue(mockEventStore.requestAccessCalled)
        }
    }
    
    func testFetchHistoricalEvents() async throws {
        let calendar = MockCalendar(title: "Test Calendar", type: .local)
        mockEventStore.calendars = [calendar]
        
        let event = MockEvent(title: "Test Event",
                            startDate: Date(),
                            endDate: Date().addingTimeInterval(3600),
                            calendar: calendar)
        mockEventStore.events = [event]
        
        let events = try await sut.fetchHistoricalEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.title, "Test Event")
    }
    
    func testFetchUpcomingEvents() async throws {
        let calendar = MockCalendar(title: "Test Calendar", type: .local)
        mockEventStore.calendars = [calendar]
        
        let event = MockEvent(title: "Future Event",
                            startDate: Date().addingTimeInterval(86400),
                            endDate: Date().addingTimeInterval(90000),
                            calendar: calendar)
        mockEventStore.events = [event]
        
        let events = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.title, "Future Event")
    }
} 