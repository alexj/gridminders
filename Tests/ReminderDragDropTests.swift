import XCTest
import EventKit
@testable import GridMinders

class ReminderDragDropTests: XCTestCase {
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

    func testAddImportantTagOnDrop() {
        let reminder = makeReminder(notes: "")
        let fetcher = ReminderFetcher()
        fetcher.modify(reminder, important: true, urgent: false, shouldPersist: false)
        XCTAssertTrue(reminder.notes?.contains("#important") ?? false, "Should add #important tag")
    }

    func testRemoveImportantTagOnDrop() {
        let reminder = makeReminder(notes: "#important #urgent")
        let fetcher = ReminderFetcher()
        fetcher.modify(reminder, important: false, urgent: true, shouldPersist: false)
        XCTAssertFalse(reminder.notes?.contains("#important") ?? false, "Should remove #important tag")
        XCTAssertTrue(reminder.notes?.contains("#urgent") ?? false, "Should keep #urgent tag")
    }

    func testAddUrgentTagOnDrop() {
        let reminder = makeReminder(notes: "")
        let fetcher = ReminderFetcher()
        fetcher.modify(reminder, important: false, urgent: true, shouldPersist: false)
        XCTAssertTrue(reminder.notes?.contains("#urgent") ?? false, "Should add #urgent tag")
    }

    func testRemoveUrgentTagOnDrop() {
        let reminder = makeReminder(notes: "#important #urgent")
        let fetcher = ReminderFetcher()
        fetcher.modify(reminder, important: true, urgent: false, shouldPersist: false)
        XCTAssertTrue(reminder.notes?.contains("#important") ?? false, "Should keep #important tag")
        XCTAssertFalse(reminder.notes?.contains("#urgent") ?? false, "Should remove #urgent tag")
    }

    func testUndoRedoTagChange() {
        let reminder = makeReminder(notes: "")
        let fetcher = ReminderFetcher()
        let undoManager = UndoManager()
        fetcher.undoManager = undoManager
        fetcher.modify(reminder, important: true, urgent: true, shouldPersist: false)
        XCTAssertTrue(reminder.notes?.contains("#important") ?? false)
        XCTAssertTrue(reminder.notes?.contains("#urgent") ?? false)
        // Undo
        undoManager.undo()
        XCTAssertFalse(reminder.notes?.contains("#important") ?? false)
        XCTAssertFalse(reminder.notes?.contains("#urgent") ?? false)
        // Redo
        undoManager.redo()
        XCTAssertTrue(reminder.notes?.contains("#important") ?? false)
        XCTAssertTrue(reminder.notes?.contains("#urgent") ?? false)
    }
}
