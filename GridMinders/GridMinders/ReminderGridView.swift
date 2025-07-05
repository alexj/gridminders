import SwiftUI
import EventKit
import AppKit
import UniformTypeIdentifiers

// MARK: - SectionView Helper
private struct Phase5SectionView: View {
    let section: String
    let parent: EKReminder
    let children: [EKReminder]
    let parentVisible: Bool
    let onDropReminder: (_ parent: EKReminder, _ droppedID: String) -> Void
    @ObservedObject var fetcher: ReminderFetcher
    @State private var isEditingTag: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Parent row (always first)
            if parentVisible {
                HStack {
                    Button(action: { fetcher.complete(parent) }) {
                        Image(systemName: "person.crop.square")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    Text(parent.title)
                        .bold()
                        .foregroundColor(.accentColor)
                    if isEditingTag {
                        SectionTagEditor(section: (section: section, reminders: [parent] + children), parent: parent, fetcher: fetcher)
                            .frame(width: 140)
                            .onDisappear { isEditingTag = false }
                    } else {
                        (Text("#p-") + Text(section).font(.caption).foregroundColor(.accentColor))
                            .onTapGesture(count: 2) { isEditingTag = true }
                            .help("Double-click to edit section tag")
                    }
                }
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(6)
            }
            // Children rows
            ForEach(children, id: \.calendarItemIdentifier) { child in
                HStack {
                    Button(action: { fetcher.complete(child) }) {
                        Image(systemName: "person")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    Text(child.title)
                        .padding(.leading, 16)
                    Text("#i-") + Text(section).font(.caption).foregroundColor(.secondary)
                }
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(4)
                .onDrag {
                    NSItemProvider(object: child.calendarItemIdentifier as NSString)
                }
                .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                    if let provider = providers.first {
                        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                            guard let droppedID = object as? String else { return }
                            onDropReminder(parent, droppedID)
                        }
                        return true
                    }
                    return false
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct ReminderGridView: View {
    @State private var showingListSelector = false
    @ObservedObject var fetcher: ReminderFetcher
    @State private var pendingDrop: (parent: EKReminder, childID: String)? = nil
    @State private var showTagPrompt = false
    @State private var newSectionTag = ""

    func onDropReminder(parent: EKReminder, droppedID: String) {
        // Use new Phase 5 tag helpers
        if let parentSection = fetcher.parseParentSectionTag(parent), !parentSection.isEmpty {
            if let dropped = fetcher.reminders.first(where: { $0.calendarItemIdentifier == droppedID }) {
                fetcher.setChildSectionTag(dropped, section: parentSection)
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
                    // Set parent as #p-<tag> in Notes
                    fetcher.setParentSectionTag(pending.parent, section: newSectionTag)
                    // Set child as #i-<tag> in Notes
                    if let dropped = fetcher.reminders.first(where: { $0.calendarItemIdentifier == pending.childID }) {
                        fetcher.setChildSectionTag(dropped, section: newSectionTag)
                    }
                    // Move parent to front so it always displays as parent
                    fetcher.moveReminderToFront(pending.parent)
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
            // PHASE 5.2: Sectioned display using new parent/child tag-based grouping
            let sectioned = fetcher.phase5SectionedReminders.filter { group in
                // Only show group if parent or any children are visible in this quadrant
                reminders.contains(where: { $0.calendarItemIdentifier == group.parent.calendarItemIdentifier }) ||
                group.children.contains(where: { reminders.contains($0) })
            }
            let sectionIDs = Set(sectioned.flatMap { [$0.parent.calendarItemIdentifier] + $0.children.map { $0.calendarItemIdentifier } })
            let ungrouped = reminders.filter { !sectionIDs.contains($0.calendarItemIdentifier) }
            List {
                ForEach(sectioned, id: \.section) { group in
                    let visibleParent = reminders.contains(where: { $0.calendarItemIdentifier == group.parent.calendarItemIdentifier })
                    let visibleChildren = group.children.filter { reminders.contains($0) }
                    Phase5SectionView(section: group.section, parent: group.parent, children: visibleChildren, parentVisible: visibleParent, onDropReminder: onDropReminder, fetcher: fetcher)
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