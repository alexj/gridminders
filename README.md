# GridMinders

**GridMinders** is a macOS SwiftUI app that visualizes your Apple Reminders in an Eisenhower 2x2 grid.

---

## Build & Run (Xcode Project)

1. **Open the Project**
   - Open `GridMinders.xcodeproj` in Xcode (version 14 or later recommended).

2. **Build the App**
   - Select the `GridMinders` app target.
   - Use `Product > Build` (or press `Cmd+B`).

3. **Run the App**
   - Use `Product > Run` (or press `Cmd+R`).
   - On first launch, you will be prompted to grant permission to access Reminders. Grant access for the app to function.

**Note:**
- Swift Package Manager (`Package.swift`) is no longer the primary build method. Use Xcode for all development and builds.
- If you encounter issues with permissions, ensure that the app has "Reminders" access in System Settings > Privacy & Security > Reminders.

---

GridMinders updates automatically whenever tasks change in the Reminders app or sync via iCloud, so the grid stays current.

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

## Section Grouping and Parent-Child Tagging

GridMinders uses an explicit parent-child tagging scheme for robust section grouping:

- **Parent reminders** are tagged in their Notes field with `#p-<section>`, e.g., `#p-ProjectX`.
- **Child reminders** are tagged in their Notes field with `#i-<section>`, e.g., `#i-ProjectX`.
- No reminder can have both a parent and child tag at the same time.
- Each group (section) can only have one parent.
- Children are always grouped under their parent in the grid.
- When a parent is renamed, all children update to match the new tag.
- When a parent is ungrouped or deleted, all children are ungrouped as well.
- Orphaned children (with `#i-<section>` but no parent with `#p-<section>`) are displayed as ungrouped, with a yellow warning icon. Clicking the warning lets you adopt the child into an available parent, ungroup it, or cancel.
- Tags are normalized: spaces, colons, and special characters are replaced with dashes; multiple dashes are collapsed.

**Legacy:** The old `#section-Name` tag is no longer used for grouping.

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
- Section grouping is based on explicit parent-child tags in Notes: `#p-<section>` for parents and `#i-<section>` for children. Orphaned children are visually flagged and can be resolved in-app.
