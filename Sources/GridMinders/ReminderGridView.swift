import SwiftUI
import EventKit
import AppKit
import UniformTypeIdentifiers

struct ReminderGridView: View {
    @State private var showingListSelector = false
    @ObservedObject var fetcher: ReminderFetcher

    func categorize(_ reminder: EKReminder) -> (important: Bool, urgent: Bool) {
        // Phase 2: Updated logic for 'important' and 'urgent'
        let now = Date()
        let calendar = Calendar.current
        var urgent = false
        var important = false

        // Urgent: overdue OR due in next 48h OR tag 'urgent'
        if let due = reminder.dueDateComponents?.date {
            if due < now {
                urgent = true
            } else if due <= now.addingTimeInterval(48 * 60 * 60) {
                urgent = true
            }
        }
        if let tags = reminder.value(forKey: "structuredLocation") as? [String] {
            // Defensive: EventKit doesn't have tags, but in case of extension
            urgent = urgent || tags.contains(where: { $0.localizedCaseInsensitiveContains("urgent") })
        } else if let notes = reminder.notes {
            // Fallback: treat #urgent in notes as a tag
            urgent = urgent || notes.localizedCaseInsensitiveContains("#urgent")
        }
        // Also check title for [urgent] as a workaround
        urgent = urgent || reminder.title.localizedCaseInsensitiveContains("urgent")

        // Important: high priority OR tag 'important'
        important = reminder.priority == 1
        if let tags = reminder.value(forKey: "structuredLocation") as? [String] {
            important = important || tags.contains(where: { $0.localizedCaseInsensitiveContains("important") })
        } else if let notes = reminder.notes {
            important = important || notes.localizedCaseInsensitiveContains("#important")
        }
        important = important || reminder.title.localizedCaseInsensitiveContains("important")

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
            List(reminders, id: \.calendarItemIdentifier) { reminder in
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
                    if let reminder = fetcher.reminders.first(where: { $0.calendarItemIdentifier == idString }) {
                        fetcher.modify(reminder, important: important, urgent: urgent)
                    }
                }
            }
        }
        return true
    }
}
