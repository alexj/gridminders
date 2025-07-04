import SwiftUI
import EventKit
import AppKit
import UniformTypeIdentifiers

// MARK: - SectionView Helper
private struct SectionView: View {
    let section: (section: String, reminders: [EKReminder])
    let visibleReminders: [EKReminder]
    @ObservedObject var fetcher: ReminderFetcher

    var parent: EKReminder? {
        section.reminders.first { reminder in
            let normTitle = reminder.title.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: "")
            let normSection = section.section.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: "")
            return normTitle == normSection
        }
    }
    var body: some View {
        // Always render parent+children as a single block, preserving order
        let parentID = parent?.calendarItemIdentifier
        let parentInQuadrant = parentID != nil && visibleReminders.contains(where: { $0.calendarItemIdentifier == parentID })
        let visibleIDs = Set(visibleReminders.map { $0.calendarItemIdentifier })
        // Only show section if parent or any children are present in quadrant
        if parentInQuadrant || section.reminders.contains(where: { $0.calendarItemIdentifier != parentID && visibleIDs.contains($0.calendarItemIdentifier) }) {
            VStack(alignment: .leading, spacing: 0) {
                // Parent row (always first)
                if let parent = parent {
                    HStack {
                        if parentInQuadrant {
                            Button(action: {
                                fetcher.complete(parent)
                            }) {
                                Image(systemName: "checkmark.circle")
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            Text(parent.title)
                                .bold()
                                .onDrag {
                                    NSItemProvider(object: ("section:" + section.section) as NSString)
                                }
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
                            Text(parent.title)
                                .bold()
                                .foregroundColor(.gray)
                        }
                    }
                    .onTapGesture(count: 2) {
                        if parentInQuadrant, let url = URL(string: "x-apple-reminder://\(parent.calendarItemIdentifier)") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                // Children rows (indented, in section.reminders order)
                ForEach(section.reminders, id: \.calendarItemIdentifier) { reminder in
                    if reminder.calendarItemIdentifier != parentID && visibleIDs.contains(reminder.calendarItemIdentifier) {
                        HStack {
                            Button(action: {
                                fetcher.complete(reminder)
                            }) {
                                Image(systemName: "checkmark.circle")
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            Text(reminder.title)
                                .padding(.leading, 16)
                                .onDrag {
                                    NSItemProvider(object: reminder.calendarItemIdentifier as NSString)
                                }
                        }
                        .onTapGesture(count: 2) {
                            if let url = URL(string: "x-apple-reminder://\(reminder.calendarItemIdentifier)") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
        }
    }

}


struct ReminderGridView: View {
    @State private var showingListSelector = false
    @ObservedObject var fetcher: ReminderFetcher

    func categorize(_ reminder: EKReminder) -> (important: Bool, urgent: Bool) {
        // Phase 2: Updated logic for 'important' and 'urgent'
        var urgent = false
        var important = false

        // Urgent: ONLY if #urgent tag is present (case-insensitive, in title or notes)
        if let notes = reminder.notes {
            urgent = notes.localizedCaseInsensitiveContains("#urgent")
        }
        urgent = urgent || reminder.title.localizedCaseInsensitiveContains("urgent")

        // Important: ONLY if #important tag is present (case-insensitive, in title or notes)
        if let notes = reminder.notes {
            important = notes.localizedCaseInsensitiveContains("#important")
        }
        important = important || reminder.title.localizedCaseInsensitiveContains("#important")

        return (important, urgent)
    }

    private func quadrant(_ reminder: EKReminder) -> Int {
        let result = categorize(reminder)
        switch (result.important, result.urgent) {
        case (true, true): return 1
        case (true, false): return 2
        case (false, true): return 3
        default: return 4
        }
    }

    var body: some View {
        let list = fetcher.filteredReminders()
        let q1 = list.filter { quadrant($0) == 1 }
        let q2 = list.filter { quadrant($0) == 2 }
        let q3 = list.filter { quadrant($0) == 3 }
        let q4 = list.filter { quadrant($0) == 4 }

        return VStack {
            HStack {
                Button(action: { showingListSelector = true }) {
                    Label("Select Lists", systemImage: "list.bullet")
                        .padding(6)
                }
                .sheet(isPresented: $showingListSelector) {
                    ListSelectorView(fetcher: fetcher, isPresented: $showingListSelector)
                }
                Spacer()
            }
            .padding([.top, .horizontal])
            HStack {
                quadrantView(title: "Important & Urgent", reminders: q1, important: true, urgent: true)
                quadrantView(title: "Important & Not Urgent", reminders: q2, important: true, urgent: false)
            }
            HStack {
                quadrantView(title: "Not Important & Urgent", reminders: q3, important: false, urgent: true)
                quadrantView(title: "Not Important & Not Urgent", reminders: q4, important: false, urgent: false)
            }
        }
        .padding()
    }

    private func quadrantView(title: String, reminders: [EKReminder], important: Bool, urgent: Bool) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            // Sectioned display using tag-based grouping
            // Only include sections where at least one child is in this quadrant
            let sectioned = fetcher.sectionedReminders.filter { section in
                section.reminders.contains(where: { reminders.contains($0) })
            }
            // The order of sectioned is preserved from sectionedReminders (parent first, then children)
            let sectionIDs = Set(sectioned.flatMap { $0.reminders.map { $0.calendarItemIdentifier } })
            let ungrouped = reminders.filter { !sectionIDs.contains($0.calendarItemIdentifier) }
            List {
                ForEach(sectioned, id: \.section) { section in
                    let visibleReminders = section.reminders.filter { reminders.contains($0) }
                    SectionView(section: section, visibleReminders: visibleReminders, fetcher: fetcher)
                }
                // Ungrouped reminders
                ForEach(ungrouped, id: \.calendarItemIdentifier) { reminder in
                    HStack {
                        Button(action: {
                            fetcher.complete(reminder)
                        }) {
                            Image(systemName: "checkmark.circle")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        Text(reminder.title)
                            .onDrag {
                                NSItemProvider(object: reminder.calendarItemIdentifier as NSString)
                            }
                    }
                    .onTapGesture(count: 2) {
                        if let url = URL(string: "x-apple-reminder://\(reminder.calendarItemIdentifier)") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                handleDrop(providers: providers, important: important, urgent: urgent)
            }
        }
        .frame(maxWidth: .infinity)
        .border(Color.gray)
    }

    private func handleDrop(providers: [NSItemProvider], important: Bool, urgent: Bool) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let id = object as? NSString else { return }
                let idString = id as String
                DispatchQueue.main.async {
                    if idString.hasPrefix("section:") {
                        // Section drag: extract section name
                        let sectionName = String(idString.dropFirst("section:".count))
                        // Find all reminders in this section
                        let sectionReminders = fetcher.reminders.filter { reminder in
                            // Use the same parseSectionTag logic as ReminderFetcher
                            let sources: [String?] = [reminder.title, reminder.notes]
                            for textOpt in sources {
                                guard let text = textOpt else { continue }
                                let pattern = "#section-([A-Za-z0-9_-]+)"
                                if let match = text.range(of: pattern, options: .regularExpression) {
                                    let name = text[match].replacingOccurrences(of: "#section-", with: "")
                                    if name.caseInsensitiveCompare(sectionName) == .orderedSame { return true }
                                }
                            }
                            return false
                        }
                        // Optionally set undoManager from environment if available
                        if fetcher.undoManager == nil, let window = NSApp.keyWindow {
                            fetcher.undoManager = window.undoManager
                        }
                        for reminder in sectionReminders {
                            fetcher.modify(reminder, important: important, urgent: urgent)
                        }
                    } else if let reminder = fetcher.reminders.first(where: { $0.calendarItemIdentifier == idString }) {
                        // Single reminder drag
                        // Optionally set undoManager from environment if available
                        if fetcher.undoManager == nil, let window = NSApp.keyWindow {
                            fetcher.undoManager = window.undoManager
                        }
                        fetcher.modify(reminder, important: important, urgent: urgent)
                    }
                }
            }
        }
        return true
    }
}
