# GridMinders App: Change Strategy & Phases

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

---

## Phase 4: Dock Icon Integration
- Add a dock icon for the app
- Implement logic to open or focus the app when the dock icon is clicked
- Ensure compatibility with macOS conventions
- Test dock icon behavior across different app states

---

## Phase 5: Final QA & Documentation
- Comprehensive testing of all new features and changes
- Update user documentation and help guides
- Gather user feedback (if possible)
- Prepare for release

---

## Notes
- Each phase should be developed and tested independently before merging.
- Prioritize backward compatibility and user experience.
- Document any architectural changes or new dependencies introduced during implementation.
