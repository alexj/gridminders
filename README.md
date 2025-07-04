# GridMinders

GridMinders is a simple macOS SwiftUI app that visualizes your Apple Reminders in an Eisenhower 2x2 grid.
The reminders list updates automatically whenever tasks change in the Reminders app or sync via iCloud, so the grid stays current.

The app requests permission to access the Reminders database using `EventKit`. Completed tasks are filtered out so only open reminders appear. Tasks are categorized as:

- **Important** if they are tagged with '#important' (case-insensitive, in the title or notes).
- **Urgent** if they are tagged with '#urgent' (case-insensitive, in the title or notes).

**Enhanced Drag-and-Drop:**
- Drag reminders into the "important" or "urgent" quadrants to automatically add `#important` or `#urgent` tags to the reminder's notes.
- Drag reminders out of those quadrants to remove the respective tag.
- Tag changes are undoable using Cmd-Z (undo/redo).
- The UI updates instantly after any drag-and-drop change.

The four quadrants are:

1. Important & Urgent
2. Important & Not Urgent
3. Not Important & Urgent
4. Not Important & Not Urgent

Click the checkmark next to a task to mark it complete. Double-click a task to open it directly in the Reminders app.
You can also drag a reminder from one quadrant to another:
- Dropping a reminder into an important quadrant automatically marks it high
  priority.
- Dropping one into an urgent quadrant assigns it a due date of today.
- Dragging an urgent reminder into a non‑urgent quadrant removes its due date.

## List Selection & Filtering (Phase 1)

You can now choose which reminder lists (calendars) are used as sources for grid items:
- Click the **Select Lists** button at the top of the app window.
- In the dialog, check the lists you want to include (or exclude, using the advanced toggle).
- By default, reminders from all lists are shown.
- Your selection is saved and restored automatically.

## Building & Running

The project is a Swift Package. You can build and run from the command line:

```bash
swift run
```

This will launch the GridMinders app on your Mac.
