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
    
    func testEmptyCalendarScenarios() async throws {
        // Test with no calendars
        mockEventStore.calendars = []
        var events = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(events.count, 0, "Should return empty array when no calendars exist")
        
        // Test with calendars but no events
        let emptyCalendar = MockCalendar(title: "Empty Calendar", type: .local)
        mockEventStore.calendars = [emptyCalendar]
        mockEventStore.events = []
        events = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(events.count, 0, "Should return empty array when calendars contain no events")
        
        // Test with multiple empty calendars
        let anotherEmptyCalendar = MockCalendar(title: "Another Empty Calendar", type: .subscription)
        mockEventStore.calendars = [emptyCalendar, anotherEmptyCalendar]
        events = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(events.count, 0, "Should return empty array when multiple calendars exist but contain no events")
    }
    
    func testSpanningEvents() async throws {
        let calendar = MockCalendar(title: "Test Calendar", type: .local)
        mockEventStore.calendars = [calendar]
        
        let now = Date()
        let historicalBoundary = Calendar.current.date(byAdding: .year, value: -1, to: now)!
        let futureBoundary = Calendar.current.date(byAdding: .day, value: 14, to: now)!
        
        // Event that spans across historical boundary
        let spanningHistoricalEvent = MockEvent(
            title: "Spanning Historical Event",
            startDate: historicalBoundary.addingTimeInterval(-3600), // 1 hour before boundary
            endDate: historicalBoundary.addingTimeInterval(3600),    // 1 hour after boundary
            calendar: calendar
        )
        
        // Event that spans across future boundary
        let spanningFutureEvent = MockEvent(
            title: "Spanning Future Event",
            startDate: futureBoundary.addingTimeInterval(-3600), // 1 hour before boundary
            endDate: futureBoundary.addingTimeInterval(3600),    // 1 hour after boundary
            calendar: calendar
        )
        
        // All-day event
        let allDayEvent = MockEvent(
            title: "All Day Event",
            startDate: Calendar.current.startOfDay(for: now),
            endDate: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!,
            calendar: calendar
        )
        
        // Test historical events
        mockEventStore.events = [spanningHistoricalEvent]
        var events = try await sut.fetchHistoricalEvents()
        XCTAssertEqual(events.count, 0, "Should not include events that start before historical boundary")
        
        // Test future events
        mockEventStore.events = [spanningFutureEvent]
        events = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(events.count, 1, "Should include events that start before future boundary")
        
        // Test all-day event
        mockEventStore.events = [allDayEvent]
        events = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(events.count, 1, "Should include all-day events")
        XCTAssertEqual(events.first?.title, "All Day Event")
    }
    
    func testCalendarTypeFiltering() async throws {
        // Set up calendars of different types
        let localCalendar = MockCalendar(title: "Local Calendar", type: .local)
        let subscriptionCalendar = MockCalendar(title: "Subscription Calendar", type: .subscription)
        let birthdayCalendar = MockCalendar(title: "Birthday Calendar", type: .birthday)
        let holidayCalendar = MockCalendar(title: "Holiday Calendar", type: .subscription)
        
        mockEventStore.calendars = [
            localCalendar,
            subscriptionCalendar,
            birthdayCalendar,
            holidayCalendar
        ]
        
        let now = Date()
        let events = [
            MockEvent(
                title: "Local Event",
                startDate: now.addingTimeInterval(3600),
                endDate: now.addingTimeInterval(7200),
                calendar: localCalendar
            ),
            MockEvent(
                title: "Subscription Event",
                startDate: now.addingTimeInterval(3600),
                endDate: now.addingTimeInterval(7200),
                calendar: subscriptionCalendar
            ),
            MockEvent(
                title: "Birthday Event",
                startDate: now.addingTimeInterval(3600),
                endDate: now.addingTimeInterval(7200),
                calendar: birthdayCalendar
            ),
            MockEvent(
                title: "Holiday Event",
                startDate: now.addingTimeInterval(3600),
                endDate: now.addingTimeInterval(7200),
                calendar: holidayCalendar
            )
        ]
        mockEventStore.events = events
        
        // Test with no filtering
        var fetchedEvents = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(fetchedEvents.count, 4, "Should include events from all calendar types when no filtering")
        
        // Test filtering subscription calendars
        sut = CalendarManager(
            eventStore: mockEventStore,
            outputFormatter: outputFormatter,
            blacklistedCalendars: Set(["Subscription Calendar", "Holiday Calendar"])
        )
        fetchedEvents = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(fetchedEvents.count, 2, "Should exclude events from blacklisted subscription calendars")
        XCTAssertTrue(fetchedEvents.contains { $0.title == "Local Event" })
        XCTAssertTrue(fetchedEvents.contains { $0.title == "Birthday Event" })
        
        // Test whitelisting specific calendar types
        sut = CalendarManager(
            eventStore: mockEventStore,
            outputFormatter: outputFormatter,
            whitelistedCalendars: Set(["Birthday Calendar", "Holiday Calendar"])
        )
        fetchedEvents = try await sut.fetchUpcomingEvents()
        XCTAssertEqual(fetchedEvents.count, 2, "Should only include events from whitelisted calendars")
        XCTAssertTrue(fetchedEvents.contains { $0.title == "Birthday Event" })
        XCTAssertTrue(fetchedEvents.contains { $0.title == "Holiday Event" })
    }
    
    func testBlacklistedCalendars() async throws {
        // Set up calendars
        let workCalendar = MockCalendar(title: "Work", type: .local)
        let personalCalendar = MockCalendar(title: "Personal", type: .local)
        mockEventStore.calendars = [workCalendar, personalCalendar]
        
        // Set up events
        let now = Date()
        let events = [
            MockEvent(
                title: "Work Meeting",
                startDate: now.addingTimeInterval(3600),
                endDate: now.addingTimeInterval(7200),
                calendar: workCalendar
            ),
            MockEvent(
                title: "Personal Appointment",
                startDate: now.addingTimeInterval(3600),
                endDate: now.addingTimeInterval(7200),
                calendar: personalCalendar
            )
        ]
        mockEventStore.events = events
        
        // Create CalendarManager with blacklisted calendar
        sut = CalendarManager(
            eventStore: mockEventStore,
            outputFormatter: outputFormatter,
            blacklistedCalendars: ["Work"]
        )
        
        let filteredEvents = try await sut.fetchUpcomingEvents()
        
        XCTAssertEqual(filteredEvents.count, 1, "Should only return events from non-blacklisted calendars")
        XCTAssertEqual(filteredEvents[0].title, "Personal Appointment", "Should only include personal event")
    }
    
    func testWhitelistedCalendars() async throws {
        // Set up calendars
        let workCalendar = MockCalendar(title: "Work", type: .local)
        let personalCalendar = MockCalendar(title: "Personal", type: .local)
        let familyCalendar = MockCalendar(title: "Family", type: .local)
        mockEventStore.calendars = [workCalendar, personalCalendar, familyCalendar]
        
        // Set up events
        let now = Date()
        let events = [
            MockEvent(
                title: "Work Meeting",
                startDate: now.addingTimeInterval(3600),
                endDate: now.addingTimeInterval(7200),
                calendar: workCalendar
            ),
            MockEvent(
                title: "Personal Appointment",
                startDate: now.addingTimeInterval(3600),
                endDate: now.addingTimeInterval(7200),
                calendar: personalCalendar
            ),
            MockEvent(
                title: "Family Dinner",
                startDate: now.addingTimeInterval(3600),
                endDate: now.addingTimeInterval(7200),
                calendar: familyCalendar
            )
        ]
        mockEventStore.events = events
        
        // Create CalendarManager with whitelisted calendars
        sut = CalendarManager(
            eventStore: mockEventStore,
            outputFormatter: outputFormatter,
            whitelistedCalendars: ["Work", "Personal"]
        )
        
        let filteredEvents = try await sut.fetchUpcomingEvents()
        
        XCTAssertEqual(filteredEvents.count, 2, "Should only return events from whitelisted calendars")
        XCTAssertTrue(filteredEvents.contains { $0.title == "Work Meeting" }, "Should include work event")
        XCTAssertTrue(filteredEvents.contains { $0.title == "Personal Appointment" }, "Should include personal event")
        XCTAssertFalse(filteredEvents.contains { $0.title == "Family Dinner" }, "Should not include family event")
    }
    
    func testMultipleCalendarEvents() async throws {
        // Set up calendars of different types
        let workCalendar = MockCalendar(title: "Work", type: .local)
        let personalCalendar = MockCalendar(title: "Personal", type: .local)
        let sharedCalendar = MockCalendar(title: "Shared", type: .subscription)
        mockEventStore.calendars = [workCalendar, personalCalendar, sharedCalendar]
        
        // Set up events with different times
        let now = Date()
        let events = [
            MockEvent(
                title: "Late Work Meeting",
                startDate: now.addingTimeInterval(7200), // 2 hours from now
                endDate: now.addingTimeInterval(10800),
                calendar: workCalendar
            ),
            MockEvent(
                title: "Early Personal Appointment",
                startDate: now.addingTimeInterval(3600), // 1 hour from now
                endDate: now.addingTimeInterval(7200),
                calendar: personalCalendar
            ),
            MockEvent(
                title: "Shared Team Event",
                startDate: now.addingTimeInterval(5400), // 1.5 hours from now
                endDate: now.addingTimeInterval(9000),
                calendar: sharedCalendar
            )
        ]
        mockEventStore.events = events
        
        // Test fetching and ordering of events
        let fetchedEvents = try await sut.fetchUpcomingEvents()
        
        XCTAssertEqual(fetchedEvents.count, 3, "Should return all events from valid calendars")
        
        // Verify chronological ordering
        XCTAssertEqual(fetchedEvents[0].title, "Early Personal Appointment", "First event should be earliest")
        XCTAssertEqual(fetchedEvents[1].title, "Shared Team Event", "Second event should be middle")
        XCTAssertEqual(fetchedEvents[2].title, "Late Work Meeting", "Third event should be latest")
    }
} 