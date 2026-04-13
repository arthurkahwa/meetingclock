# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Developer Profile

The developer is an expert in Swift, iOS, SwiftUI, SwiftData, and Swift concurrency. Skip basic explanations of these technologies. Use precise terminology, discuss trade-offs directly, and engage at an advanced level.

## Commands

```bash
# Build the app
xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build

# Run all tests
xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 -destination 'platform=iOS Simulator,name=iPhone 17' test

# Run unit tests only
xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MeetClock02Tests test

# Run UI tests only
xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MeetClock02UITests test
```

## Architecture

**MeetClock** tracks the real cost of meetings by calculating time × participant hourly rates. Data is persisted via SwiftData with CloudKit sync, propagating across iPhone, macOS, and Apple Watch.

### Stack
- **SwiftUI** for UI (`NavigationSplitView`, `NavigationStack`, `Form`, `TimelineView`)
- **SwiftData** for persistence (`@Query`, `@Bindable`, `@Model`)
- **CloudKit** for cross-platform sync (iPhone, iPad, macOS, Apple Watch)
- **Swift 6.2** with Swift Approachable Concurrency
- **Targets**: iOS 26.2 (iPhone + iPad), macOS 26, watchOS 11

### View Hierarchy & Navigation

The root container adapts to platform and size class. All platforms share the same SwiftData store via CloudKit.

```
RootView  ──────────────────────────────────────────────────────────
 ├── [iPad / macOS]  NavigationSplitView
 │    ├── Sidebar: MeetingListView    ← @Query list; create/delete controls
 │    └── Detail:  MeetingDetailView ← runtime + cost + participants + controls
 │
 ├── [iPhone]  NavigationStack
 │    └── MeetingListView            ← @Query list; create/delete controls
 │         └── MeetingDetailView     ← pushed on selection
 │              ├── Portrait:  full detail (runtime, cost, participants, controls)
 │              └── Landscape: MeetingLiveBoardView (runtime small, cost max-size)
 │
 └── [Apple Watch]  WatchRootView
      └── WatchCostView              ← latest running meeting cost only

Shared across all detail contexts:
  MeetingDetailView
  ├── MeetingRunView          ← TimelineView clock + cost + start/pause/stop controls
  ├── EditMeetingView         ← @Bindable MeetingModel (name, dates, notes)
  ├── EditMeetingParticipantView ← @Bindable MeetingParticipant
  └── ParticipantPickerView (sheet)
```

### Platform Layouts

#### iPad & macOS — `NavigationSplitView`
`MeetingListView` in the sidebar; `MeetingDetailView` in the detail column. The detail shows the full meeting: running time, cost, participant list, and start/pause/stop controls side by side. `NavigationSplitView` handles column visibility automatically per platform.

#### iPhone — `NavigationStack`
`MeetingListView` is the root. Selecting a meeting pushes `MeetingDetailView`. Layout adapts to orientation using `verticalSizeClass`:

- **Portrait** (`verticalSizeClass == .regular`): full `MeetingDetailView` — runtime, cost, participant list, controls.
- **Landscape** (`verticalSizeClass == .compact`): `MeetingLiveBoardView` — elapsed time in a smaller font at the top, meeting cost rendered as large as the screen allows (`minimumScaleFactor` or `font(.system(size:))` fitted to available height). No participant list, no controls visible — the screen becomes a cost display.

#### Apple Watch — `WatchRootView`
Shows the **most recently started running meeting's cost**, live-updated every second via `TimelineView`. No list, no controls — read-only cost glance. If no meeting is running, show the cost of the last completed meeting.

### Meeting List View

`MeetingListView` is shared as the sidebar (iPad/macOS) and root (iPhone). It:
- Shows all configured meetings via `@Query` with sort and search.
- **Running meetings** show a live cost ticker in the list row, updated every second inside a `TimelineView` scoped to that row. A visual indicator (e.g. pulsing dot) marks the meeting as active.
- **Create**: toolbar button inserts a new `MeetingModel` into the context and navigates/selects it immediately.
- **Delete**: swipe-to-delete on iPhone; toolbar Edit mode or right-click → Delete on iPad/macOS. Deleting a meeting does not delete its participants (they remain in the global pool).

### Meeting Run View

`MeetingRunView` is embedded inside `MeetingDetailView` and `MeetingLiveBoardView`. It displays:
- **Elapsed time** — running clock, smaller in landscape iPhone.
- **Total cost** — large font; fills available space in `MeetingLiveBoardView`.
- **Graphical controls** — start, pause, and stop buttons (hidden in `MeetingLiveBoardView`).

All live values wrap in a `TimelineView(.periodic(from:by:1))`. Cost and elapsed time are recomputed from stored timestamps on every tick — no in-memory accumulation.

### Meeting Timer Architecture

Each meeting runs an **independent timer** that survives backgrounding. The approach:
- On **start**: persist `meetingStart = Date.now` and `isRunning = true` to SwiftData.
- On **pause**: persist `pausedAt = Date.now`; stop UI updates.
- On **resume**: add `Date.now - pausedAt` to a persisted `totalPausedDuration: TimeInterval`; clear `pausedAt`.
- On **stop**: call `endMeeting()` — sets `meetingEnd`, materializes `meetingLength` and `meetingCost`, sets `isRunning = false`.
- **Elapsed time** at any moment: `Date.now - meetingStart - totalPausedDuration`
- **Background safety**: because elapsed time is always derived from stored `Date` values, the timer requires no background task or `BGTaskScheduler` registration — the value is correct whenever the app returns to foreground.

`MeetingModel` needs two additional persisted properties for pause support:

| Property | Type | Purpose |
|----------|------|---------|
| `pausedAt` | `Date?` | Set when paused; `nil` when running or stopped |
| `totalPausedDuration` | `TimeInterval` | Cumulative seconds spent paused |

### Participant Management

Participants are managed from `EditMeetingView`:
- **Add**: presents `ParticipantPickerView` as a sheet. Shows a searchable list of all `MeetingParticipant` records in the store. If the desired participant doesn't exist, the user can create one inline — it is inserted into the context and immediately added to the meeting.
- **Remove**: unlinks the participant from `meeting.participants` — does **not** delete the `MeetingParticipant` record, preserving it in the global pool for other meetings.
- **Edit**: navigates to `EditMeetingParticipantView` for the selected participant. Edits affect the shared record and will reflect across all meetings that participant is assigned to.

### Data Model

`MeetingModel` is the root aggregate. `MeetingParticipant` records exist as a **global pool** — they are created independently and assigned to meetings. A participant can appear in multiple meetings, so the relationship is **many-to-many**.

Both are `@Model` classes. Only `MeetingModel.self` is registered in the `modelContainer`; SwiftData infers `MeetingParticipant` from the relationship graph.

```
MeetingModel  >──< MeetingParticipant   (many-to-many)
  meetingCost = meetingLength × Σ(participant.hourlyRate) / 3600
```

**MeetingModel** (primary aggregate)
| Property | Type | Purpose |
|----------|------|---------|
| `meetingName` | String | Meeting title |
| `meetingStart` | Date | Start time |
| `meetingEnd` | Date | End time |
| `meetingLength` | TimeInterval | Duration in seconds |
| `meetingCost` | Double | Total cost — `meetingLength × Σ hourlyRates / 3600` |
| `meetingNotes` | String | Free-form notes |
| `isRunning` | Bool | Whether the meeting is currently active; gates resource availability |
| `participants` | `[MeetingParticipant]` | Assigned participants (many-to-many); removing unlinks, does not delete |

`endMeeting()` sets `meetingEnd = .now`, materializes `meetingLength` and `meetingCost`, then sets `isRunning = false` — freeing any resource participants.

**MeetingParticipant** (child)
| Property | Type | Purpose |
|----------|------|---------|
| `firstName` | String | — |
| `lastName` | String | — |
| `hourlyRate` | Double | Normalized per-hour rate (always stored as hourly regardless of input rate type) |
| `rateType` | `RateType` | `.hourly` or `.daily` — controls UI input; rate is normalized to hourly before storing |
| `participantType` | `ParticipantType` | `.human` or `.resource` |
| `currencyCode` | `String` | ISO 4217 currency code for this participant's rate (e.g. `"USD"`, `"EUR"`) |
| `meetings` | `[MeetingModel]` | Inverse of many-to-many; all meetings this participant is assigned to |

`RateType` and `ParticipantType` are `String`-raw-value enums conforming to `Codable` — SwiftData persists them via `Codable`; plain Swift enums without a raw type are not supported.

### Concurrency & Resource Rules

- Multiple meetings can run simultaneously (`isRunning == true` on many `MeetingModel` instances at once).
- **Human** participants (`participantType == .human`) can attend any number of concurrent meetings.
- **Resource** participants (`participantType == .resource`) can only be in one running meeting at a time.
- Enforcement is in `MeetingModel.canAdd(_:)` — call this before adding any participant. It fetches all `isRunning` meetings via `modelContext` and rejects a resource already present in another running meeting.
- `modelContext` is `nil` on uninserted objects; `canAdd` returns `true` in that case (permissive — an uninserted participant has no conflicting assignments yet).
- Resources are freed implicitly by `endMeeting()` setting `isRunning = false` — no explicit detach needed.
- `#Predicate` is from `Foundation`, not `SwiftData` — files using `#Predicate` must `import Foundation`.

### Cost Calculation Rules

The total meeting cost is the sum of every participant's individual cost for the duration of the meeting:

```
participantCost = elapsed(s) × hourlyRate / 3600          (in participant's currency)
meetingCost     = Σ participantCost  (all assigned participants)
```

- `meetingCost` is a **persisted** `Double`, not a computed property. SwiftData `#Predicate` queries cannot reference computed properties and CloudKit cannot sync them — always materialize the value at save time.
- During an active meeting, cost is **recomputed live** on every `TimelineView` tick from `elapsed = Date.now - meetingStart - totalPausedDuration`. The persisted `meetingCost` is only written on `endMeeting()`.
- `meetingLength` is in **seconds**, `hourlyRate` is per **hour** — always divide by 3600. An off-by-3600× bug here is silent and easy to miss.
- Every participant contributes their full rate for the full meeting duration. If per-participant time tracking is added later, the formula and model must change.
- Daily rate normalizes to hourly at **write time**: `hourlyRate = dailyRate / 8` (8-hour workday). The raw input rate is not stored — only the derived hourly value. The UI reconstructs the display value from `rateType` + `hourlyRate`.
- `hourlyRate` on `MeetingParticipant` is always the normalized hourly value. Never branch on `rateType` inside the cost formula.

### Currency

Each `MeetingParticipant` stores its own `currencyCode` (ISO 4217 `String`). Participants in the same meeting can have different currencies.

- Use `Locale.current.currency?.identifier` as the default when creating a participant.
- Use `FormatStyle.Currency(code:)` (or `.currency(code:)`) for all monetary display — never format cost values manually.
- Because participants can have mixed currencies, `meetingCost` alone is insufficient for display when currencies differ. The meeting cost display must either:
  - **Group by currency** — show a per-currency subtotal (e.g. USD 120 + EUR 80), or
  - **Convert to a base currency** — requires exchange rate data (out of scope unless explicitly added).
- `meetingCost` persists the **raw sum in mixed units** for historical record; the UI is responsible for meaningful presentation.

### Key Patterns
- `@Bindable` for two-way binding to SwiftData model objects in edit views
- Dynamic `@Query` built in `init` parameters (see `MeetingView`) — the only way to pass runtime filter/sort values into SwiftData queries
- `navigationDestination(for:)` with typed `NavigationStack` path — add items to `path` to navigate
- `foregroundStyle()` not `foregroundColor()`
- Modern Swift concurrency only — no `DispatchQueue`
- Use `NavigationPath` (type-erased) when a `NavigationStack` needs to push more than one type — typed `[T]` paths silently drop pushes of other types
- `NavigationSplitView` detail column needs its own `NavigationStack` wrapper for `NavigationLink(value:)` to work within it

## Environment Quirks

### SourceKit false positives
SourceKit reports "Cannot find type X in scope" after file edits — always stale-index noise. Verify with `xcodebuild`; never act on SourceKit errors alone.

### Folder-based project
`project.pbxproj` has zero `.swift` references. New `.swift` and resource files in target directories are compiled automatically — no project registration needed.

### Build verification simulator
Use `platform=iOS Simulator,name=iPhone 17` for build/test commands.
