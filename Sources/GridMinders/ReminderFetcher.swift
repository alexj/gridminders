import EventKit
import Combine

final class ReminderFetcher: ObservableObject {
    var undoManager: UndoManager?

    @Published private(set) var calendars: [EKCalendar] = []
    @Published var includedCalendarIDs: Set<String> = [] // IDs of included lists
    @Published var excludedCalendarIDs: Set<String> = [] // IDs of excluded lists
    @Published var useExclusion: Bool = false // false = include mode, true = exclude mode

    private let includedKey = "IncludedCalendarIDs"
    private let excludedKey = "ExcludedCalendarIDs"
    private let useExclusionKey = "UseExclusion"

    func loadUserSelection() {
        if let included = UserDefaults.standard.array(forKey: includedKey) as? [String] {
            includedCalendarIDs = Set(included)
        }
        if let excluded = UserDefaults.standard.array(forKey: excludedKey) as? [String] {
            excludedCalendarIDs = Set(excluded)
        }
        useExclusion = UserDefaults.standard.bool(forKey: useExclusionKey)
    }

    func saveUserSelection() {
        UserDefaults.standard.set(Array(includedCalendarIDs), forKey: includedKey)
        UserDefaults.standard.set(Array(excludedCalendarIDs), forKey: excludedKey)
        UserDefaults.standard.set(useExclusion, forKey: useExclusionKey)
    }

    @Published private(set) var reminders: [EKReminder] = []
    private let store = EKEventStore()
    private var changeCancellable: AnyCancellable?

    init() {
        changeCancellable = NotificationCenter.default.publisher(for: .EKEventStoreChanged, object: nil)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.store.reset()
                self.loadReminders()
                self.loadCalendars()
            }
        loadUserSelection()
    }

    func requestAccess() {
        store.requestAccess(to: .reminder) { granted, _ in
            if granted {
                self.loadReminders()
                self.loadCalendars()
            }
        }
    }

    private func loadReminders() {
        let predicate = store.predicateForReminders(in: nil)
        store.fetchReminders(matching: predicate) { reminders in
            DispatchQueue.main.async {
                let incomplete = reminders?.filter { !$0.isCompleted } ?? []
                self.reminders = incomplete
            }
        }
    }

    func loadCalendars() {
        let allCalendars = store.calendars(for: .reminder)
        DispatchQueue.main.async {
            self.calendars = allCalendars
        }
    }

    // Returns reminders filtered by user selection
    func filteredReminders() -> [EKReminder] {
        if useExclusion {
            if excludedCalendarIDs.isEmpty { return reminders }
            return reminders.filter { !excludedCalendarIDs.contains($0.calendar.calendarIdentifier) }
        } else {
            if includedCalendarIDs.isEmpty { return reminders }
            return reminders.filter { includedCalendarIDs.contains($0.calendar.calendarIdentifier) }
        }
    }

    func complete(_ reminder: EKReminder) {
        reminder.isCompleted = true
        do {
            try store.save(reminder, commit: true)
            loadReminders()
        } catch {
            print("Failed to complete reminder", error)
        }
    }

    /// Update a reminder's importance and urgency based on drag and drop.
    /// - Parameters:
    ///   - reminder: The reminder to modify.
    ///   - important: If true, the reminder is given the highest priority.
    ///   - urgent: If true, the reminder is assigned a due date of today. If
    ///     false, any existing due date is cleared.
    /// Enhanced: Also manages #important and #urgent tags in notes, and supports undo.
    func modify(_ reminder: EKReminder, important: Bool, urgent: Bool, shouldPersist: Bool = true) {
        let oldPriority = reminder.priority
        let oldDue = reminder.dueDateComponents
        let oldNotes = reminder.notes

        // Priority
        reminder.priority = important ? 1 : 0
        // Do NOT modify due date; always preserve existing dueDateComponents

        // Tag logic (in notes)
        var notes = reminder.notes ?? ""
        func hasTag(_ tag: String) -> Bool {
            notes.localizedCaseInsensitiveContains(tag)
        }
        func addTag(_ tag: String) {
            if !hasTag(tag) {
                if notes.isEmpty {
                    notes = tag
                } else {
                    notes += " " + tag
                }
            }
        }
        func removeTag(_ tag: String) {
            // Remove tag if it is surrounded by word boundaries or spaces
            let pattern = "(\\s|^)" + NSRegularExpression.escapedPattern(for: tag) + "(\\s|$)"
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            notes = regex.stringByReplacingMatches(in: notes, options: [], range: NSRange(location: 0, length: notes.utf16.count), withTemplate: " ")
            // Clean up multiple spaces and trim
            notes = notes.replacingOccurrences(of: "  ", with: " ")
            notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Important tag
        if important {
            addTag("#important")
        } else {
            removeTag("#important")
        }
        // Urgent tag
        if urgent {
            addTag("#urgent")
        } else {
            removeTag("#urgent")
        }
        reminder.notes = notes.isEmpty ? nil : notes
        // Undo support
        if let undoManager = undoManager {
            let oldNotesCopy = oldNotes
            let oldPriorityCopy = oldPriority
            let oldDueCopy = oldDue
            undoManager.registerUndo(withTarget: self) { target in
                reminder.priority = oldPriorityCopy
                reminder.dueDateComponents = oldDueCopy
                reminder.notes = oldNotesCopy
                if shouldPersist {
                    do {
                        try target.store.save(reminder, commit: true)
                        target.loadReminders()
                    } catch {
                        print("Failed to undo reminder modification", error)
                    }
                }
            }
            undoManager.setActionName("Modify Reminder Tags")
        }
        if shouldPersist {
            do {
                try store.save(reminder, commit: true)
                loadReminders()
            } catch {
                print("Failed to modify reminder", error)
            }
        }
    }
}
