# Unified Meeting View Design

**Date:** 2026-04-05
**Branch:** ber02
**Status:** Approved

## Goal

Replace the two-step create/edit flow (`MeetingDetailView` → "Edit" → `EditMeetingView`) with a single unified `MeetingView` used for both creating and editing a meeting. Merge meeting info fields and run controls into one always-editable view.

## Current State

- **`MeetingDetailView`** — shows timer (`MeetingRunView`), participant list, and an "Edit" `NavigationLink`
- **`EditMeetingView`** — separate navigation destination for editing name, dates, notes, currency
- **Create flow**: "Add Meeting" → `MeetingDetailView` → tap "Edit" → `EditMeetingView`
- **Edit flow**: `MeetingDetailView` → tap "Edit" → `EditMeetingView`
- The `isRunning` branch in `RootView` toggles the destination between `EditMeetingView` and `MeetingDetailView`

## Target State

One view: `MeetingView`. Used for create and edit. No "Edit" button. Fields always editable.

## Layout

`MeetingView` is a `List` with three sections:

```
MeetingView(meeting: MeetingModel)
 ├── Section: Info
 │    ├── TextField → meetingName
 │    ├── DatePicker → meetingStart   (read-only Text while isRunning)
 │    ├── DatePicker → meetingEnd     (hidden while isRunning)
 │    ├── CurrencyPicker → meetingCurrencyCode
 │    └── TextField (multiline) → meetingNotes
 │
 ├── Section: Timer
 │    └── MeetingRunView (embedded unchanged)
 │
 └── Section: Participants
      ├── ForEach rows → NavigationLink → EditMeetingParticipantView
      └── "Add Participant" button → ParticipantPickerView (sheet)
```

## Field Behavior

| Field | While stopped | While running |
|---|---|---|
| `meetingName` | Editable `TextField` | Editable `TextField` |
| `meetingStart` | `DatePicker` | Read-only `Text` (live start is set) |
| `meetingEnd` | `DatePicker` | Hidden (not yet determined) |
| `meetingCurrencyCode` | Picker | Picker |
| `meetingNotes` | Multiline `TextField` | Multiline `TextField` |

## Navigation

- `navigationTitle` driven by `meeting.meetingName` via `@Bindable`
- No toolbar "Edit" button
- "Add Participant" button in the Participants section triggers `ParticipantPickerView` as a sheet (unchanged)
- Participant rows are `NavigationLink` → `EditMeetingParticipantView` (unchanged)

## Landscape (iPhone)

`MeetingLiveBoardView` overlays `MeetingView` on compact vertical size class — no changes to that view or its trigger condition.

## Files

### Deleted
- `Views/MeetingView/MeetingDetailView.swift`
- `Views/MeetingView/EditMeetingView.swift`

### Created
- `Views/MeetingView/MeetingView.swift`

### Modified
- `Views/RootView.swift` — `navigationDestination(for: MeetingModel.self)` always renders `MeetingView`; remove the `isRunning` branching logic
- `Views/MeetingListView.swift` — remove any stale references to deleted views (likely none)

### Untouched
- `MeetingRunView.swift`
- `MeetingLiveBoardView.swift`
- `ParticipantPickerView.swift`
- `EditMeetingParticipantView.swift`
- All models, services, app entry point

## Out of Scope

- Changes to participant management flow
- Landscape / `MeetingLiveBoardView` behavior
- Exchange rate or cost calculation logic
- Watch or macOS layout changes
