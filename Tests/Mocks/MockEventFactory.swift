import Foundation
import EventKit
@testable import NovelEventsExtractor

class MockEventFactory {
    static func createCalendar(title: String, type: EKCalendarType = .local) -> MockCalendar {
        return MockCalendar(title: title, type: type)
    }
    
    static func createEvent(title: String, 
                          startDate: Date,
                          duration: TimeInterval = 3600,
                          calendar: CalendarType) -> MockEvent {
        return MockEvent(title: title,
                        startDate: startDate,
                        endDate: startDate.addingTimeInterval(duration),
                        calendar: calendar)
    }
    
    static func createTestData() -> (calendars: [MockCalendar], events: [MockEvent]) {
        let workCalendar = createCalendar(title: "Work")
        let personalCalendar = createCalendar(title: "Personal")
        let birthdaysCalendar = createCalendar(title: "Birthdays")
        
        let now = Date()
        let calendar = Calendar.current
        var events: [MockEvent] = []
        
        // Regular work meetings (every Tuesday and Thursday at 10 AM)
        var date = calendar.date(byAdding: .month, value: -12, to: now)!
        while date < now {
            if calendar.component(.weekday, from: date) == 3 || // Tuesday
               calendar.component(.weekday, from: date) == 5 {  // Thursday
                let meetingDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date)!
                events.append(createEvent(title: "Team Sync",
                                       startDate: meetingDate,
                                       calendar: workCalendar))
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // Monthly social events
        date = calendar.date(byAdding: .month, value: -12, to: now)!
        while date < now {
            let eventDate = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: date)!
            events.append(createEvent(title: "Monthly Game Night",
                                   startDate: eventDate,
                                   duration: 7200,
                                   calendar: personalCalendar))
            date = calendar.date(byAdding: .month, value: 1, to: date)!
        }
        
        // Birthdays
        events.append(createEvent(title: "Alice's Birthday", 
                               startDate: calendar.date(from: DateComponents(year: 2024, month: 3, day: 15))!,
                               calendar: birthdaysCalendar))
        events.append(createEvent(title: "Bob's Birthday",
                               startDate: calendar.date(from: DateComponents(year: 2024, month: 6, day: 22))!,
                               calendar: birthdaysCalendar))
        
        // Novel events (upcoming)
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: now)!
        events.append(createEvent(title: "Dentist Appointment",
                               startDate: calendar.date(bySettingHour: 14, minute: 30, second: 0, of: nextWeek)!,
                               calendar: personalCalendar))
        
        let twoWeeks = calendar.date(byAdding: .day, value: 14, to: now)!
        events.append(createEvent(title: "Annual Performance Review",
                               startDate: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: twoWeeks)!,
                               calendar: workCalendar))
        
        return ([workCalendar, personalCalendar, birthdaysCalendar], events)
    }
} 