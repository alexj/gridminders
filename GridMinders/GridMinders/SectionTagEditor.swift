import SwiftUI
import EventKit

struct SectionTagEditor: View {
    let section: (section: String, reminders: [EKReminder])
    let parent: EKReminder?
    @ObservedObject var fetcher: ReminderFetcher

    @State private var editingTag: String = ""

    var body: some View {
        HStack(spacing: 4) {
            Text("#p-")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("tag", text: $editingTag, onCommit: {
                let trimmed = editingTag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let parent = parent, !trimmed.isEmpty, trimmed != section.section else {
                    editingTag = section.section
                    return
                }
                // Normalize: replace space, colon, or special char (other than dash) with dash; collapse dashes
                var normalized = trimmed.lowercased().map { c -> Character in
                    if c.isLetter || c.isNumber || c == "-" { return c }
                    return "-"
                }.reduce("") { partial, c in partial + String(c) }
                // Collapse multiple dashes
                while normalized.contains("--") { normalized = normalized.replacingOccurrences(of: "--", with: "-") }
                normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                // Enforce uniqueness for parents
                var unique = normalized
                var n = 2
                while fetcher.reminders.contains(where: { $0.calendarItemIdentifier != parent.calendarItemIdentifier && fetcher.parseParentSectionTag($0)?.caseInsensitiveCompare(unique) == .orderedSame }) {
                    unique = normalized + String(n)
                    n += 1
                }
                // Set parent tag
                fetcher.setParentSectionTag(parent, section: unique)
                // Update all children to match new tag
                for child in section.reminders where child.calendarItemIdentifier != parent.calendarItemIdentifier {
                    fetcher.setChildSectionTag(child, section: unique)
                }
                editingTag = unique
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
