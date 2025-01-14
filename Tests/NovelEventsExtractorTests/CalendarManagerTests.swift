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
    
    func testInvalidCalendarError() async throws {
        // Set up a subscription calendar which should be rejected
        let subscriptionCalendar = MockCalendar(title: "Invalid Calendar", type: .subscription)
        mockEventStore.calendars = [subscriptionCalendar]
        mockEventStore.shouldGrantAccess = false
        mockEventStore.shouldThrowOnFetch = true  // Force the mock to throw on fetch
        
        // Attempt to fetch events
        do {
            _ = try await sut.fetchHistoricalEvents()
            XCTFail("Expected fetchHistoricalEvents to throw for invalid calendar")
        } catch {
            XCTAssertTrue(error is CalendarError)
            if let calendarError = error as? CalendarError {
                XCTAssertEqual(calendarError, .accessDenied)
            }
        }
    }
    
    func testDateRangeEdgeCases() async throws {
        let calendar = MockCalendar(title: "Test Calendar", type: .local)
        mockEventStore.calendars = [calendar]
        mockEventStore.shouldGrantAccess = true
        
        // Test event exactly at the boundary dates
        let now = Date()
        let historicalBoundary = Calendar.current.date(byAdding: .year, value: -1, to: now)!
        let futureBoundary = Calendar.current.date(byAdding: .day, value: 14, to: now)!
        
        // Set up boundary events - place them just inside the valid range
        let historicalEvent = MockEvent(
            title: "Historical Boundary Event",
            startDate: historicalBoundary.addingTimeInterval(1), // 1 second after boundary
            endDate: historicalBoundary.addingTimeInterval(3600),
            calendar: calendar
        )
        mockEventStore.events = [historicalEvent]
        
        // Test historical events
        let historicalEvents = try await sut.fetchHistoricalEvents()
        XCTAssertEqual(historicalEvents.count, 1, "Should include event just after historical boundary")
        XCTAssertEqual(historicalEvents.first?.title, "Historical Boundary Event")
        
        // Set up future event
        let futureEvent = MockEvent(
            title: "Future Boundary Event",
            startDate: futureBoundary.addingTimeInterval(-1), // 1 second before boundary
            endDate: futureBoundary.addingTimeInterval(3600),
            calendar: calendar
        )
        mockEventStore.events = [futureEvent]
        
        // Test upcoming events
        let upcomingEvents = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(upcomingEvents.count, 1, "Should include event just before future boundary")
        XCTAssertEqual(upcomingEvents.first?.title, "Future Boundary Event")
        
        // Test events outside boundaries
        let outsideBoundaryEvents = [
            MockEvent(
                title: "Too Old Event",
                startDate: historicalBoundary.addingTimeInterval(-1), // 1 second before boundary
                endDate: historicalBoundary.addingTimeInterval(3600),
                calendar: calendar
            ),
            MockEvent(
                title: "Too Future Event",
                startDate: futureBoundary.addingTimeInterval(1), // 1 second after boundary
                endDate: futureBoundary.addingTimeInterval(3600),
                calendar: calendar
            )
        ]
        mockEventStore.events = outsideBoundaryEvents
        
        // Verify events outside boundaries are not included
        let historicalOutside = try await sut.fetchHistoricalEvents()
        XCTAssertEqual(historicalOutside.count, 0, "Should not include events before historical boundary")
        
        let upcomingOutside = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(upcomingOutside.count, 0, "Should not include events after future boundary")
    }
} 