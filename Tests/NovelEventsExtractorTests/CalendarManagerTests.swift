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
    
    func testBlacklistedCalendars() async throws {
        // Set up calendars
        let workCalendar = MockCalendar(title: "Work", type: .local)
        let personalCalendar = MockCalendar(title: "Personal", type: .local)
        mockEventStore.calendars = [workCalendar, personalCalendar]
        
        // Create events in both calendars
        let workEvent = MockEvent(
            title: "Work Meeting",
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            calendar: workCalendar
        )
        let personalEvent = MockEvent(
            title: "Personal Appointment",
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            calendar: personalCalendar
        )
        mockEventStore.events = [workEvent, personalEvent]
        
        // Create CalendarManager with blacklisted Work calendar
        sut = CalendarManager(
            eventStore: mockEventStore,
            outputFormatter: outputFormatter,
            blacklistedCalendars: Set(["Work"])
        )
        
        // Test upcoming events
        let events = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(events.count, 1, "Should only include events from non-blacklisted calendars")
        XCTAssertEqual(events.first?.title, "Personal Appointment")
    }
    
    func testWhitelistedCalendars() async throws {
        // Set up calendars
        let workCalendar = MockCalendar(title: "Work", type: .local)
        let personalCalendar = MockCalendar(title: "Personal", type: .local)
        let birthdayCalendar = MockCalendar(title: "Birthdays", type: .local)
        mockEventStore.calendars = [workCalendar, personalCalendar, birthdayCalendar]
        
        // Create events in all calendars
        let workEvent = MockEvent(
            title: "Work Meeting",
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            calendar: workCalendar
        )
        let personalEvent = MockEvent(
            title: "Personal Appointment",
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            calendar: personalCalendar
        )
        let birthdayEvent = MockEvent(
            title: "Birthday Party",
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            calendar: birthdayCalendar
        )
        mockEventStore.events = [workEvent, personalEvent, birthdayEvent]
        
        // Create CalendarManager with whitelisted Work and Personal calendars
        sut = CalendarManager(
            eventStore: mockEventStore,
            outputFormatter: outputFormatter,
            blacklistedCalendars: Set(),
            whitelistedCalendars: Set(["Work", "Personal"])
        )
        
        // Test upcoming events
        let events = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(events.count, 2, "Should only include events from whitelisted calendars")
        XCTAssertTrue(events.contains { $0.title == "Work Meeting" })
        XCTAssertTrue(events.contains { $0.title == "Personal Appointment" })
        XCTAssertFalse(events.contains { $0.title == "Birthday Party" })
    }
    
    func testMixedCalendarFiltering() async throws {
        // Set up calendars
        let workCalendar = MockCalendar(title: "Work", type: .local)
        let personalCalendar = MockCalendar(title: "Personal", type: .local)
        let birthdayCalendar = MockCalendar(title: "Birthdays", type: .local)
        let holidayCalendar = MockCalendar(title: "Holidays", type: .local)
        mockEventStore.calendars = [workCalendar, personalCalendar, birthdayCalendar, holidayCalendar]
        
        // Create events in all calendars
        let workEvent = MockEvent(
            title: "Work Meeting",
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            calendar: workCalendar
        )
        let personalEvent = MockEvent(
            title: "Personal Appointment",
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            calendar: personalCalendar
        )
        let birthdayEvent = MockEvent(
            title: "Birthday Party",
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            calendar: birthdayCalendar
        )
        let holidayEvent = MockEvent(
            title: "Holiday",
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            calendar: holidayCalendar
        )
        mockEventStore.events = [workEvent, personalEvent, birthdayEvent, holidayEvent]
        
        // Create CalendarManager with:
        // - Whitelisted: Work, Personal, Birthdays
        // - Blacklisted: Work (should override whitelist)
        sut = CalendarManager(
            eventStore: mockEventStore,
            outputFormatter: outputFormatter,
            blacklistedCalendars: Set(["Work"]),
            whitelistedCalendars: Set(["Work", "Personal", "Birthdays"])
        )
        
        // Test upcoming events
        let events = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(events.count, 2, "Should include events from whitelisted calendars except blacklisted ones")
        XCTAssertFalse(events.contains { $0.title == "Work Meeting" }, "Blacklist should override whitelist")
        XCTAssertTrue(events.contains { $0.title == "Personal Appointment" })
        XCTAssertTrue(events.contains { $0.title == "Birthday Party" })
        XCTAssertFalse(events.contains { $0.title == "Holiday" }, "Non-whitelisted calendar should be excluded")
    }
    
    func testMultipleCalendarEvents() async throws {
        // Set up calendars with different types
        let workCalendar = MockCalendar(title: "Work", type: .local)
        let personalCalendar = MockCalendar(title: "Personal", type: .local)
        let sharedCalendar = MockCalendar(title: "Shared", type: .subscription)
        mockEventStore.calendars = [workCalendar, personalCalendar, sharedCalendar]
        
        // Create multiple events in each calendar at different times
        let now = Date()
        let events = [
            MockEvent(
                title: "Work Meeting 1",
                startDate: now.addingTimeInterval(3600),
                endDate: now.addingTimeInterval(7200),
                calendar: workCalendar
            ),
            MockEvent(
                title: "Work Meeting 2",
                startDate: now.addingTimeInterval(10800),
                endDate: now.addingTimeInterval(14400),
                calendar: workCalendar
            ),
            MockEvent(
                title: "Personal Appointment",
                startDate: now.addingTimeInterval(5400),
                endDate: now.addingTimeInterval(9000),
                calendar: personalCalendar
            ),
            MockEvent(
                title: "Shared Event",
                startDate: now.addingTimeInterval(7200),
                endDate: now.addingTimeInterval(10800),
                calendar: sharedCalendar
            )
        ]
        mockEventStore.events = events
        
        // Test fetching all events without any filtering
        let fetchedEvents = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(fetchedEvents.count, 4, "Should fetch all events from all calendars")
        
        // Verify events are from different calendars
        let workEvents = fetchedEvents.filter { $0.calendar.title == "Work" }
        let personalEvents = fetchedEvents.filter { $0.calendar.title == "Personal" }
        let sharedEvents = fetchedEvents.filter { $0.calendar.title == "Shared" }
        
        XCTAssertEqual(workEvents.count, 2, "Should have 2 work events")
        XCTAssertEqual(personalEvents.count, 1, "Should have 1 personal event")
        XCTAssertEqual(sharedEvents.count, 1, "Should have 1 shared event")
        
        // Verify chronological order
        let sortedEvents = fetchedEvents.sorted { $0.startDate < $1.startDate }
        for (actual, expected) in zip(fetchedEvents, sortedEvents) {
            XCTAssertEqual(actual.startDate, expected.startDate, "Events should be in chronological order")
            XCTAssertEqual(actual.title, expected.title, "Events should maintain their titles")
        }
    }
} 