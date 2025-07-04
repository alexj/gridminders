# GridMinders

GridMinders is a simple macOS SwiftUI app that visualizes your Apple Reminders in an Eisenhower 2x2 grid.
The reminders list updates automatically whenever tasks change in the Reminders app or sync via iCloud, so the grid stays current.

The app requests permission to access the Reminders database using `EventKit`. Completed tasks are filtered out so only open reminders appear.

## Quadrant Logic and Tagging

- **Important** if they are tagged with `#important` (case-insensitive, in the title or notes).
- **Urgent** if they are tagged with `#urgent` (case-insensitive, in the title or notes).
- Only tags determine importance/urgency—due dates and priorities are not used for quadrant logic.

## Drag-and-Drop Features

- Drag reminders into the "important" or "urgent" quadrants to automatically add `#important` or `#urgent` tags.
- Drag reminders out of those quadrants to remove the respective tag.
- Tag changes are undoable using Cmd-Z (undo/redo).
- The UI updates instantly after any drag-and-drop change.
- Dragging a section parent moves all reminders in that section to the new quadrant and updates tags for all items in the section.

## Section Grouping

- Reminders can be grouped into sections using the `#section-Name` tag (case-insensitive, in the title or notes).
- Section parents and children are displayed together in the correct quadrant.
- When a section is moved to a different quadrant, all reminders in that section update their tags accordingly.

## Sorting and Manual Reordering

- Items with 'high' priority are always at the top of their section, overruling manual order.
- All other reminders are shown in the same order as in the Reminders app, as much as possible.
- You can manually reorder reminders within a quadrant or section by dragging them up or down.
- **Note:** Due to EventKit limitations, manual sorting is only preserved within GridMinders. The sort order may be different from what you see in the Apple Reminders app, and changes made in GridMinders will not sync back to Reminders.

## The Four Quadrants

1. Important & Urgent
2. Important & Not Urgent
3. Not Important & Urgent
4. Not Important & Not Urgent

## Other Features

- Click the checkmark next to a task to mark it complete.
- Double-click a task to open it directly in the Reminders app.
- List selection and filtering: Click **Select Lists** to choose which reminder lists (calendars) are used as sources for grid items. Your selection is saved automatically.

## Requirements
macOS 13+
iOS 16+

## Building & Running

The project is a Swift Package. You can build and run from the command line:

```bash
swift run
```

This will launch the GridMinders app on your Mac.

---

**Limitations**
- Manual sorting order is not synced to the Reminders app due to EventKit API limitations.
- Quadrant assignment is based solely on tags (`#important`, `#urgent`).
- Section grouping is based on the `#section-Name` tag.
