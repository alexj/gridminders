import SwiftUI
import EventKit
import AppKit
import UniformTypeIdentifiers

// MARK: - SectionView Helper
private struct SectionView: View {
    let section: (section: String, reminders: [EKReminder])
    let visibleReminders: [EKReminder]
    let onDropReminder: (_ parent: EKReminder, _ droppedID: String) -> Void
    @ObservedObject var fetcher: ReminderFetcher

    var parent: EKReminder? {
        // Prefer reminder with explicit #section-<short> tag in title or notes
        section.reminders.first(where: { r in
            let tag = "#section-" + section.section
            let titleHasTag = r.title.range(of: tag, options: .caseInsensitive) != nil
            let notesHasTag = (r.notes?.range(of: tag, options: .caseInsensitive) ?? nil) != nil
            return titleHasTag || notesHasTag
        }) ?? section.reminders.first
    }
    @State private var pendingDrop: (parent: EKReminder, childID: String)? = nil
    @State private var showTagPrompt = false
    @State private var newSectionTag = ""

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
                            // Show section tag or fallback for clarity
                            if !section.section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("#\(section.section)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .cornerRadius(8)
                                    .foregroundColor(.secondary)
                                    .accessibilityLabel("Section tag: \(section.section)")
                            } else {
                                Text("No Tag")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.10))
                                    .cornerRadius(8)
                                    .foregroundColor(.gray)
                                    .accessibilityLabel("No section tag")
                            }
                            // Inline section tag editing UI
                            SectionTagEditor(section: section, parent: parent, fetcher: fetcher)

                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
                            Text(parent.title)
                                .bold()
                                .foregroundColor(.gray)
                        }
                    }
                    .onTapGesture(count: 2) {
                        if parentInQuadrant {
                            let uuid = parent.calendarItemIdentifier
                            let url = URL(string: "x-apple-reminderkit://REMCDReminder/\(uuid)/details")
                            if let url = url, NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
                                NSWorkspace.shared.open(url)
                            } else {
                                let alert = NSAlert()
                                alert.messageText = "Cannot open reminder in Reminders app"
                                alert.informativeText = "Your system does not support opening reminders directly. This feature may not be available on your version of macOS."
                                alert.runModal()
                            }
                        }
                    }
                }
                // Children rows (indented, in section.reminders order)
                ForEach(section.reminders.indices, id: \.self) { index in
                    let reminder = section.reminders[index]
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
                        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                            if let provider = providers.first {
                                _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                                    guard let droppedID = object as? String else { return }
                                    let parent = section.reminders[index]
                                    onDropReminder(parent, droppedID)
                                }
                                return true
                            }
                            return false
                        }
                        .onTapGesture(count: 2) {
                            let uuid = reminder.calendarItemIdentifier
                            let url = URL(string: "x-apple-reminderkit://REMCDReminder/\(uuid)/details")
                            if let url = url, NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
                                NSWorkspace.shared.open(url)
                            } else {
                                let alert = NSAlert()
                                alert.messageText = "Cannot open reminder in Reminders app"
                                alert.informativeText = "Your system does not support opening reminders directly. This feature may not be available on your version of macOS."
                                alert.runModal()
                            }
                        }
                    }
                }
                .onMove { indices, newOffset in
                    fetcher.moveReminderInSection(section: section.section, fromOffsets: indices, toOffset: newOffset)
                }
            }
        }
    }
}

struct ReminderGridView: View {
    @State private var showingListSelector = false
    @ObservedObject var fetcher: ReminderFetcher
    @State private var pendingDrop: (parent: EKReminder, childID: String)? = nil
    @State private var showTagPrompt = false
    @State private var newSectionTag = ""

    func onDropReminder(parent: EKReminder, droppedID: String) {
        let parentTag = fetcher.parseSectionTag(parent)
        if let tag = parentTag, !tag.isEmpty {
            if let dropped = fetcher.reminders.first(where: { $0.calendarItemIdentifier == droppedID }) {
                fetcher.setSectionTag(dropped, tag: tag, enforceUnique: false)
            }
        } else {
            pendingDrop = (parent: parent, childID: droppedID)
            showTagPrompt = true
        }
    }

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
        .alert("Parent has no section tag.", isPresented: $showTagPrompt, actions: {
            TextField("Section tag", text: $newSectionTag)
            Button("OK") {
                if let pending = pendingDrop, !newSectionTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    fetcher.setSectionTag(pending.parent, tag: newSectionTag)
                    if let dropped = fetcher.reminders.first(where: { $0.calendarItemIdentifier == pending.childID }) {
                        fetcher.setSectionTag(dropped, tag: newSectionTag)
                    }
                }
                pendingDrop = nil
                newSectionTag = ""
            }
            Button("Cancel", role: .cancel) {
                pendingDrop = nil
                newSectionTag = ""
            }
        }, message: {
            Text("Enter a tag for this section. The tag will be applied to both parent and child.")
        })
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
                    SectionView(section: section, visibleReminders: visibleReminders, onDropReminder: onDropReminder, fetcher: fetcher)
                }
                // Ungrouped reminders
                ForEach(ungrouped.indices, id: \.self) { index in
                    let reminder = ungrouped[index]
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
                    .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                        if let provider = providers.first {
                            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                                guard let droppedID = object as? String else { return }
                                onDropReminder(parent: reminder, droppedID: droppedID)
                            }
                            return true
                        }
                        return false
                    }
                    .onTapGesture(count: 2) {
                        let uuid = reminder.calendarItemIdentifier
                        let url = URL(string: "x-apple-reminderkit://REMCDReminder/\(uuid)/details")
                        if let url = url, NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
                            NSWorkspace.shared.open(url)
                        } else {
                            let alert = NSAlert()
                            alert.messageText = "Cannot open reminder in Reminders app"
                            alert.informativeText = "Your system does not support opening reminders directly. This feature may not be available on your version of macOS."
                            alert.runModal()
                        }
                    }
                }
            }
        }
    }
}