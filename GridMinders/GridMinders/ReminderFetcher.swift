import EventKit
import Combine

final class ReminderFetcher: ObservableObject {
    // Moves a reminder within the reminders array to a new index (for ungrouped reminders)
    func moveReminder(fromOffsets: IndexSet, toOffset: Int) {
        var newReminders = reminders
        newReminders.move(fromOffsets: fromOffsets, toOffset: toOffset)
        reminders = newReminders
        // NOTE: EventKit does not provide a public API to persist manual order changes to the Reminders app.
        // This only affects the order in GridMinders.
    }
    // Moves a reminder within a section (for sectioned reminders)
    func moveReminderInSection(section: String, fromOffsets: IndexSet, toOffset: Int) {
        // Find all reminders in this section
        let sectionReminders = reminders.filter { parseSectionTag($0) == section }
        guard !sectionReminders.isEmpty else { return }

        // Get the IDs in section, in current order
        var sectionIDs = sectionReminders.map { $0.calendarItemIdentifier }
        sectionIDs.move(fromOffsets: fromOffsets, toOffset: toOffset)
        // Rebuild reminders array with section reordered
        var newReminders = reminders
        var sectionIdx = 0
        for i in 0..<newReminders.count {
            if parseSectionTag(newReminders[i]) == section {
                let newID = sectionIDs[sectionIdx]
                if newReminders[i].calendarItemIdentifier != newID,
                   let swapIdx = newReminders.firstIndex(where: { $0.calendarItemIdentifier == newID }) {
                    newReminders.swapAt(i, swapIdx)
                }
                sectionIdx += 1
                if sectionIdx >= sectionIDs.count { break }
            }
        }
        reminders = newReminders
        // NOTE: EventKit does not provide a public API to persist manual order changes to the Reminders app.
        // This only affects the order in GridMinders.
    }
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

    /// Computed: Returns reminders grouped by #section-Name tag
    var sectionedReminders: [(section: String, reminders: [EKReminder])] {
        return Dictionary(grouping: reminders) { reminder -> String? in
            parseSectionTag(reminder)
        }
        .compactMap { key, value -> (String, [EKReminder])? in
            guard let section = key else { return nil }
            // Sort reminders: parent (title matches section name) first, then others
            let prettySection = prettifySectionName(section)
            func normalize(_ s: String) -> String {
                s.lowercased()
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "_", with: "")
            }
            // Build a lookup for reminders' original order
            let orderLookup: [String: Int] = reminders.enumerated().reduce(into: [:]) { dict, pair in
                dict[pair.element.calendarItemIdentifier] = pair.offset
            }
            let sorted = value.sorted { lhs, rhs in
                let lhsIsParent = normalize(lhs.title) == normalize(prettySection)
                let rhsIsParent = normalize(rhs.title) == normalize(prettySection)
                if lhsIsParent && !rhsIsParent { return true }
                if !lhsIsParent && rhsIsParent { return false }
                // High priority always before others (priority == 1 is high)
                if lhs.priority == 1 && rhs.priority != 1 { return true }
                if lhs.priority != 1 && rhs.priority == 1 { return false }
                // Otherwise, preserve Reminders app order
                let lhsOrder = orderLookup[lhs.calendarItemIdentifier] ?? Int.max
                let rhsOrder = orderLookup[rhs.calendarItemIdentifier] ?? Int.max
                return lhsOrder < rhsOrder
            }
            return (section, sorted)
        }
        // Sort sections alphabetically (pretty-printed)
        .sorted { prettifySectionName($0.0).localizedCaseInsensitiveCompare(prettifySectionName($1.0)) == .orderedAscending }
        .map { (prettifySectionName($0.0), $0.1) }
    }

    /// Computed: Returns reminders without a #section tag
    var ungroupedReminders: [EKReminder] {
        reminders.filter { parseSectionTag($0) == nil }
    }

    /// Helper: Extracts section name from #section-<short> tag in notes or title. Only explicit tags are used for grouping.
    func parseSectionTag(_ reminder: EKReminder) -> String? {
        // Look for #section-<short> in title or notes
        let sources: [String?] = [reminder.title, reminder.notes]
        let pattern = "#section-([A-Za-z0-9_-]+)"
        for textOpt in sources {
            guard let text = textOpt else { continue }
            if let match = text.range(of: pattern, options: .regularExpression) {
                let name = text[match].replacingOccurrences(of: "#section-", with: "")
                if !name.isEmpty {
                    return String(name)
                }
            }
        }
        // Do NOT fallback for grouping
        return nil
    }
    /// Normalize/truncate a string for use as a fallback section tag
    private func normalizeSectionTag(_ s: String?) -> String {
        guard let s = s else { return "" }
        let alphanumerics = s.lowercased().filter { $0.isLetter || $0.isNumber }
        return String(alphanumerics.prefix(10))
    }
    /// Check if a section tag is unique among all reminders
    func isSectionTagUnique(_ tag: String, excluding reminder: EKReminder? = nil) -> Bool {
        let allTags = reminders.compactMap { parseSectionTag($0) }
        let filtered = reminder == nil ? allTags : reminders.filter { $0 != reminder }.compactMap { parseSectionTag($0) }
        return !filtered.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
    }
    /// Set a section tag on a reminder (removes any existing section tag). Ensures uniqueness by auto-appending a number if needed. Returns the final tag used.
    @discardableResult
    func setSectionTag(_ reminder: EKReminder, tag: String, enforceUnique: Bool = true) -> String {
        removeSectionTags(reminder)
        // Enforce uniqueness (case-insensitive)
        var finalTag = tag
        if enforceUnique {
            var n = 2
            while !isSectionTagUnique(finalTag, excluding: reminder) {
                finalTag = "\(tag)\(n)"
                n += 1
            }
        }
        // Add to notes
        var notes = reminder.notes ?? ""
        if !notes.isEmpty { notes += " " }
        notes += "#section-" + finalTag
        reminder.notes = notes
        // Do NOT modify the title when setting a section tag
        do { try store.save(reminder, commit: true); loadReminders() } catch { print("Failed to set section tag", error) }
        return finalTag
    }
    /// Remove all section tags from a reminder
    func removeSectionTags(_ reminder: EKReminder) {
        var notes = reminder.notes ?? ""
        let pattern = "(\\s|^)#section-[A-Za-z0-9_-]+(\\s|$)"
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        notes = regex.stringByReplacingMatches(in: notes, options: [], range: NSRange(location: 0, length: notes.utf16.count), withTemplate: " ")
        notes = notes.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.notes = notes.isEmpty ? nil : notes
        do { try store.save(reminder, commit: true); loadReminders() } catch { print("Failed to remove section tag", error) }
    }

    /// Helper: Prettify section name for display (replace - and _ with space, capitalize words)
    private func prettifySectionName(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
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
