import XCTest
import EventKit
@testable import GridMinders

class ReminderGridViewTests: XCTestCase {
    // Helper to create a mock EKReminder
    func makeReminder(title: String = "", priority: Int = 0, dueDate: Date? = nil, notes: String? = nil) -> EKReminder {
        let store = EKEventStore()
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.priority = priority
        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }
        reminder.notes = notes
        return reminder
    }

    func testUrgentDueOverdue() {
        let overdue = Date().addingTimeInterval(-3600) // 1 hour ago
        let reminder = makeReminder(dueDate: overdue)
        let grid = ReminderGridView(fetcher: ReminderFetcher())
        XCTAssertTrue(grid.categorize(reminder).urgent, "Should be urgent if overdue")
    }

    func testUrgentDueSoon() {
        let soon = Date().addingTimeInterval(47 * 60 * 60) // 47 hours from now
        let reminder = makeReminder(dueDate: soon)
        let grid = ReminderGridView(fetcher: ReminderFetcher())
        XCTAssertTrue(grid.categorize(reminder).urgent, "Should be urgent if due within 48h")
    }

    func testUrgentTagInTitle() {
        let reminder = makeReminder(title: "[Urgent] Something", priority: 0)
        let grid = ReminderGridView(fetcher: ReminderFetcher())
        XCTAssertTrue(grid.categorize(reminder).urgent, "Should be urgent if title contains 'urgent'")
    }

    func testUrgentTagInNotes() {
        let reminder = makeReminder(notes: "#urgent")
        let grid = ReminderGridView(fetcher: ReminderFetcher())
        XCTAssertTrue(grid.categorize(reminder).urgent, "Should be urgent if notes contains #urgent")
    }

    func testImportantPriority() {
        let reminder = makeReminder(priority: 1)
        let grid = ReminderGridView(fetcher: ReminderFetcher())
        XCTAssertTrue(grid.categorize(reminder).important, "Should be important if priority is high")
    }

    func testImportantTagInTitle() {
        let reminder = makeReminder(title: "Important: Buy milk")
        let grid = ReminderGridView(fetcher: ReminderFetcher())
        XCTAssertTrue(grid.categorize(reminder).important, "Should be important if title contains 'important'")
    }

    func testImportantTagInNotes() {
        let reminder = makeReminder(notes: "#important")
        let grid = ReminderGridView(fetcher: ReminderFetcher())
        XCTAssertTrue(grid.categorize(reminder).important, "Should be important if notes contains #important")
    }
}
