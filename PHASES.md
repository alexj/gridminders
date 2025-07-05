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
  - [ ] When displaying sections in the UI, show the short tag or fallback for clarity.
  - [✔] Parent/child grouping restored and robust to tag format.
- [ ] Add drag-to-parent functionality:
  - [ ] Enable dragging one reminder onto another to make the first a child of the second.
  - [ ] On drop, assign the parent’s section tag to the child and update grouping in the UI.
  - [ ] If the drop target (parent) does not have a section tag, prompt the user to create or confirm a  short tag.
  - [ ] When a reminder is made a child, ensure it receives the parent’s section tag (remove any previous section tag from the child).
- [ ] UI/UX improvements:
  - [ ] Highlight drop targets and show a tooltip or prompt (e.g., "Make this a child of [parent title]?").
  - [ ] Allow editing of section tags for parent reminders. Modify the implementation to only show the editing interface on when the user taps a small edit icon on the row of the section title
  - [ ] When a parent reminder's section tag is renamed automatically update all child reminders to use the new tag.
  - [ ] Warn or prevent if a section tag is not unique.
  - [ ] Remove the white border around each quadrant 
  - [ ] Remove the Select Lists button from the UI and replace it with a Settings menu, following macOS conventions (accessible via the menu bar - GridMinders > Settings > Select Lists functionality)
  - [ ] Make the text size for section headers/parent Reminders two points larger and bold
  - [ ] Indent the circle icon of child items; right now the icons are all in the same spot, but the text of child items is indented -- the entire line should be indented, maintaining the same spacing between icon and reminder title
  - [ ] Add a small edit icon to the row of the section title to allow editing of the section tag.
- [ ] Update documentation and README to explain the new grouping/tagging workflow.

## Phase 5: Dock Icon Integration
- Add a dock icon for the app
- Implement logic to open or focus the app when the dock icon is clicked
- Ensure compatibility with macOS conventions
- Test dock icon behavior across different app states

---

## Phase 6: Final QA & Documentation
- Comprehensive testing of all new features and changes
- Update user documentation and help guides
- Gather user feedback (if possible)
- Prepare for release

---

## Notes
- Each phase should be developed and tested independently before merging.
- Prioritize backward compatibility and user experience.
- Document any architectural changes or new dependencies introduced during implementation.
