# GridMinders App: Change Strategy & Phases

## Project Infrastructure
- [✔] Converted app to a proper Xcode project structure (no duplicate or legacy files)
- [✔] Fixed build and linker issues (no more dynamic library output, app builds and runs as a true macOS app)
- [✔] Configured Info.plist with NSRemindersUsageDescription
- [✔] Added and configured Reminders entitlement in .entitlements file
- [✔] Debugged and verified Reminders permission prompt and access

## Overview
This document outlines a phased strategy for implementing the planned changes to the GridMinders app. Each phase is broken down into actionable items to ensure a smooth and maintainable rollout.

---

## Phase 1: List Selection & Filtering
- [✔] Add UI for users to select one or more Lists as sources for grid items
- [✔] Default behavior: show items from all lists
- [✔] Add advanced option to exclude specific lists instead of including them
- [✔] Update grid logic to only show items from selected lists (or all if none selected)
- [✔] Persist user selection (e.g., in user defaults or app state)

---

## Phase 2: Redefine 'Urgent' and 'Important'
- [✔] Update 'Urgent' definition:
  - [✔] Item is overdue
  - [✔] Item is due within the next 48 hours
  - [✔] Item has a tag of 'urgent' (case-insensitive)
- [✔] Update 'Important' definition:
  - [✔] Item has 'high' priority
  - [✔] Item has a tag of 'important' (case-insensitive)
- [✔] Refactor relevant logic and UI indicators to use new definitions
- [✔] Add/Update tests for new definitions

---

## Phase 3: Enhanced Drag-and-Drop Behavior
- [✔] Update drag-and-drop logic as follows:
  - [✔] Dropping a reminder into an important quadrant automatically tags it with 'important'
  - [✔] Dropping a reminder into an urgent quadrant automatically tags it with 'urgent'
  - [✔] Dragging an 'important' item into a not-important quadrant removes the 'important' tag
  - [✔] Dragging an 'urgent' item into a not-urgent quadrant removes the 'urgent' tag
- [✔] Update UI to reflect tag changes in real time
- [✔] Ensure undo/redo support for tag changes
- [✔] Add/Update tests for drag-and-drop behavior

### Phase 3.1: Remove use of dates in logic
- [✔] Refactor the "urgent" logic:
  - [✔] Remove all code that marks tasks as urgent based on due date or overdue status.
  - [✔] Ensure only the `#urgent` tag (case-insensitive, in title or notes) determines urgency.
- [✔] Refactor the "important" logic:
  - [✔] Remove all code that marks tasks as important based on priority or other non-tag criteria.
  - [✔] Ensure only the `#important` tag (case-insensitive, in title or notes) determines importance.
- [✔] Update all UI labels, tooltips, and documentation to clarify that urgency and importance are tag-based only.
- [✔] Update or remove any tests that check for urgency/importance based on dates or priority.
- [✔] Add/Update tests to verify that only tags control urgency and importance.
- [✔] Review and update README and help guides to reflect the new logic.

## Phase 4: Improved item handling
- [✔] Support grouping/sections of reminders:
  - [✔] Display items within a section as children of that parent within the correct quadrant. (Parent and children are now grouped by #section-Name tag. Parent must have the same #section-Name tag as children, in title or notes.)
- [✔] When a section of reminders is moved to a different quadrant:
  - [✔] All items in that section have the same tags applied or removed, as applicable.
- [✔] Items should be sorted by priority within their sections and quadrants:
  - [✔] Items with 'high' priority are always at the top of their section, overruling any manual order.
- [✔] Items within a quadrant should be sorted in the same order as in the Reminders app.
- [✔] Allow manual sorting of items by dragging within a quadrant or section:
  - [✘] Update the order in the Reminders app accordingly. (Not possible: EventKit does not support programmatic sorting. Order is local to GridMinders only.)

### Phase 4.1: Improve UX of item grouping
- [✔] Implement hybrid section tagging strategy:
  - [✔] Allow user to specify a short, unique section/group tag (e.g., `#section-Q1Plan`) for parent reminders. (Colon is not supported; dash-based tags only.)
  - [✔] Grouping and parsing logic now only recognizes `#section-<short>` tags in title or notes. Fallback/pretty names are used for display only.
  - [✔] Enforce uniqueness of section tags within the app (prompt user or auto-append a number if needed).
  - [✔] Add inline section tag editing UI so you can set or change section tags directly in the app. (SectionTagEditor.swift)
  - [✔] When displaying sections in the UI, show the short tag or fallback for clarity.
  - [✔] Parent/child grouping restored and robust to tag format.
- [ ] Add drag-to-parent functionality:
  - [ ] Enable dragging one reminder onto another to make the first a child of the second.
  - [ ] On drop, assign the parent’s section tag to the child and update grouping in the UI.
  - [ ] If the drop target (parent) does not have a section tag, prompt the user to create or confirm a  short tag.
  - [ ] When a reminder is made a child, ensure it receives the parent’s section tag (remove any previous section tag from the child).

## Phase 5: Change grouping structure

### Phase 5.1: Tagging Conventions & Parsing
- [x] Implement new tag structure:
    - [x] Parent reminders use a tag of the form `#p-<section>` in the Notes field.
    - [x] Child reminders use a tag of the form `#i-<section>` in the Notes field.
    - [x] The `<section>` part is a user-chosen identifier shared by both parent and children.
    - [x] Enforce that a reminder cannot have both a `#p-` and `#i-` tag at the same time.
- [x] Update reminder parsing logic to:
    - [x] Identify parents by `#p-<section>` in Notes.
    - [x] Identify children by `#i-<section>` in Notes.
    - [x] Group reminders by the shared `<section>` identifier.
    - [x] Treat reminders with neither tag as ungrouped.

### Phase 5.2: UI Grouping & Display
- [x] Display each group with the parent (`#p-<section>`) as the group header.
- [x] Display all children (`#i-<section>`) under the parent.
- [x] Prevent a reminder from being both parent and child in the same or different groups.

> **2025-07-05:** UI now displays each group with the parent (#p-<section>) as the header and all children (#i-<section>) under the parent, using the new tag structure. Legacy grouping and SectionView have been removed. Ready for Phase 5.3.

### Phase 5.3: Drag-and-Drop Grouping
- [ ] On drag-and-drop:
    - [ ] If the drop target (potential parent) has no group tag, prompt for a section name.
    - [ ] Assign `#p-<section>` to the drop target (parent) in Notes.
    - [ ] Assign `#i-<section>` to the dragged reminder (child) in Notes, removing any previous `#p-` or `#i-` tags from it.
    - [ ] If the parent already has a `#p-<section>` tag, assign the corresponding `#i-<section>` tag to the dragged reminder.

### Phase 5.4: Tag Editing and Consistency
- [ ] When editing a parent’s group tag (renaming the section):
    - [ ] Update the parent's tag in Notes to the new `#p-<newsection>`.
    - [ ] Update all children’s tags in Notes to `#i-<newsection>`.
    - [ ] Enforce uniqueness of section names (no two parents with the same `#p-<section>`).
- [ ] When a child is removed from a group, remove its `#i-<section>` tag from Notes.
- [ ] When a parent is deleted or ungrouped, remove its `#p-<section>` tag and update all children to remove their `#i-<section>` tags (or prompt for new grouping).

### Phase 5.5: Validation and Invariants
- [ ] On every relevant operation (add, edit, drag, drop, remove), enforce:
    - [ ] No reminder has both a `#p-` and `#i-` tag.
    - [ ] Each group has at most one parent.
    - [ ] Orphaned children (with `#i-<section>` but no parent) are handled gracefully (e.g., displayed as ungrouped or with a warning).

### Phase 5.6: Documentation
- [ ] Update in-app help and README to explain the new grouping/tagging workflow and what the special tags mean.


## Phase 6: UI/UX improvements
- [ ] Make the entire row of an item or group draggable
- [ ] make the entire area of a parent and its children a a drop target for new items to be assigned to the parent
- [ ] Highlight drop targets and show a tooltip or prompt (e.g., "Make this a child of [parent title]?").
- [ ] Allow editing of section tags for parent reminders. Modify the implementation to only show the editing interface on when the user taps the section tag capsule next to the parent title.
- [ ] When a parent reminder's section tag is renamed automatically update all child reminders to use the new tag.
- [ ] Warn or prevent if a section tag is not unique.
- [ ] Remove the white border around each quadrant 
- [ ] Remove the Select Lists button from the UI and replace it with a Settings menu, following macOS conventions (accessible via the menu bar - GridMinders > Settings > Select Lists functionality)
- [ ] when showing the Select Lists modal, alphabetize the list of lists
- [ ] Make the text size for section headers/parent Reminders two points larger and bold
- [ ] Indent the circle icon of child items; right now the icons are all in the same spot, but the text of child items is indented -- the entire line should be indented, maintaining the same spacing between icon and reminder title
- [ ] Add a small edit icon to the row of the section title to allow editing of the section tag.
- [ ] Update documentation and README to explain the new grouping/tagging workflow.

## Phase 7: Dock Icon Integration
- Add a dock icon for the app
- Implement logic to open or focus the app when the dock icon is clicked
- Ensure compatibility with macOS conventions
- Test dock icon behavior across different app states

---

## Phase 8: Final QA & Documentation
- Comprehensive testing of all new features and changes
- Update user documentation and help guides
- Gather user feedback (if possible)
- Prepare for release

---

## Notes
- Each phase should be developed and tested independently before merging.
- Prioritize backward compatibility and user experience.
- Document any architectural changes or new dependencies introduced during implementation.
