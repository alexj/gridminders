import SwiftUI
import EventKit

struct SectionTagEditor: View {
    let section: (section: String, reminders: [EKReminder])
    let parent: EKReminder?
    @ObservedObject var fetcher: ReminderFetcher

    @State private var editingTag: String = ""

    var body: some View {
        HStack(spacing: 4) {
            Text("#section-")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("tag", text: $editingTag, onCommit: {
                let trimmed = editingTag.trimmingCharacters(in: .whitespacesAndNewlines)
                if let parent = parent, !trimmed.isEmpty, trimmed != section.section {
                    let finalTag = fetcher.setSectionTag(parent, tag: trimmed)
                    // Update all children to match new tag
                    for child in section.reminders where child.calendarItemIdentifier != parent.calendarItemIdentifier {
                        fetcher.setSectionTag(child, tag: finalTag)
                    }
                    editingTag = finalTag // In case uniqueness logic changed it
                } else {
                    // Reset if invalid
                    editingTag = section.section
                }
            })
            .font(.caption)
            .frame(width: 100)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .help("Edit section tag. Must be unique. Children will be updated to match.")
        }
        .padding(.leading, 8)
        .onAppear {
            self.editingTag = section.section
        }
        .onChange(of: section.section) { newSection in
            self.editingTag = newSection
        }
        .onDrag {
            NSItemProvider(object: ("section:" + section.section) as NSString)
        }
    }
}
