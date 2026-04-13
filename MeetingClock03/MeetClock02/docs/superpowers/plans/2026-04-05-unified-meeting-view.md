# Unified Meeting View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `MeetingDetailView` + `EditMeetingView` with a single `MeetingView` — one always-editable view used for both creating and editing a meeting, with info fields, run controls, and participants in one scroll.

**Architecture:** Overwrite `MeetingDetailView.swift` in-place with the new `MeetingView` struct (avoids adding a new file to the Xcode project), then delete `EditMeetingView.swift` (one pbxproj removal). Update `RootView.swift` to remove the `isRunning` branch and route everything through `MeetingView`.

**Tech Stack:** SwiftUI, SwiftData (`@Bindable`), `Form`/`List` sections, `TimelineView` (via embedded `MeetingRunView`)

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Overwrite | `MeetClock02/Views/MeetingView/MeetingDetailView.swift` | Becomes `MeetingView` — unified info + timer + participants |
| Delete | `MeetClock02/Views/MeetingView/EditMeetingView.swift` | Absorbed into `MeetingView` |
| Modify | `MeetClock02/Views/RootView.swift` | Remove `isRunning` branch; always render `MeetingView` |

Working directory for all commands: `/Users/arthur/Developer/meetingClock/MeetingClock03/MeetClock02`

---

### Task 1: Replace MeetingDetailView.swift with MeetingView

Overwrite the file in-place so the Xcode project reference stays valid. Rename the struct from `MeetingDetailView` to `MeetingView`. The new view is a `Form` with three sections: Info (always-editable fields), Timer (embedded `MeetingRunView`), Participants (rows + Add button). The `ParticipantRowView` private struct moves here from the old file.

**Files:**
- Overwrite: `MeetClock02/Views/MeetingView/MeetingDetailView.swift`

- [ ] **Step 1: Overwrite MeetingDetailView.swift with MeetingView**

Replace the entire file content with:

```swift
// MeetClock02/Views/MeetingView/MeetingDetailView.swift

import SwiftUI
import SwiftData

struct MeetingView: View {
    @Bindable var meeting: MeetingModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(ExchangeRateService.self) private var exchangeRateService

    @State private var showingPicker = false

    var body: some View {
#if os(iOS)
        if verticalSizeClass == .compact {
            MeetingLiveBoardView(meeting: meeting)
        } else {
            meetingForm
        }
#else
        meetingForm
#endif
    }

    private var meetingForm: some View {
        Form {
            Section {
                TextField("Meeting Name", text: $meeting.meetingName)
                    .textContentType(.name)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif

                if meeting.isRunning {
                    LabeledContent("Started") {
                        Text(meeting.meetingStart, style: .time)
                    }
                } else {
                    DatePicker("Start", selection: $meeting.meetingStart,
                               displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $meeting.meetingEnd,
                               displayedComponents: [.date, .hourAndMinute])
                }

                Picker("Currency", selection: $meeting.meetingCurrencyCode) {
                    ForEach(Locale.commonISOCurrencyCodes, id: \.self) { code in
                        Text("\(code) – \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
                            .tag(code)
                    }
                }

                TextField("Notes", text: $meeting.meetingNotes, axis: .vertical)
            }

            Section {
                MeetingRunView(meeting: meeting)
            }

            Section("Participants") {
                ForEach(meeting.participants) { participant in
                    NavigationLink(destination: EditMeetingParticipantView(participant: participant)) {
                        ParticipantRowView(
                            participant: participant,
                            meetingCurrency: meeting.meetingCurrencyCode,
                            exchangeRateService: exchangeRateService
                        )
                    }
                }
                Button("Add Participant", systemImage: "person.badge.plus") {
                    showingPicker = true
                }
            }
        }
        .navigationTitle(meeting.meetingName.isEmpty ? "Meeting" : meeting.meetingName)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sheet(isPresented: $showingPicker) {
            ParticipantPickerView(meeting: meeting)
        }
    }
}

// MARK: - Participant row

private struct ParticipantRowView: View {
    let participant: MeetingParticipant
    let meetingCurrency: String
    let exchangeRateService: ExchangeRateService

    var body: some View {
        HStack {
            Image(systemName: participant.participantType == .human ? "person.fill" : "desktopcomputer")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text(displayName)
                    .font(.subheadline)

                let displayRate = participant.rateType == .daily
                    ? participant.hourlyRate * 8
                    : participant.hourlyRate
                let convertedRate = exchangeRateService.convert(
                    displayRate,
                    from: participant.currencyCode,
                    to: meetingCurrency
                )
                Text(convertedRate, format: .currency(code: meetingCurrency))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                + Text(participant.rateType == .daily ? "/day" : "/hr")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        participant.participantType == .resource
            ? participant.firstName
            : "\(participant.firstName) \(participant.lastName)"
    }
}
```

- [ ] **Step 2: Build to verify Task 1 compiles**

```bash
xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

If `MeetingDetailView` is still referenced anywhere, you'll see "cannot find type 'MeetingDetailView'" — fix those references first (Task 2 handles `RootView.swift`; check for any other callers).

- [ ] **Step 3: Commit**

```bash
git add MeetClock02/Views/MeetingView/MeetingDetailView.swift
git commit -m "refactor: replace MeetingDetailView with unified MeetingView"
```

---

### Task 2: Update RootView.swift to use MeetingView

Remove the `isRunning` branch from both `SplitViewHost` and `StackViewHost`. Both now unconditionally render `MeetingView`.

**Files:**
- Modify: `MeetClock02/Views/RootView.swift`

- [ ] **Step 1: Replace SplitViewHost detail block**

In `SplitViewHost.body`, replace:

```swift
detail: {
    if let meeting = selectedMeeting {
        if meeting.isRunning {
            EditMeetingView(meeting: meeting)
        } else {
            MeetingDetailView(meeting: meeting)
        }
    } else {
        ContentUnavailableView("Select a Meeting",
                               systemImage: "clock.badge.questionmark",
                               description: Text("Choose a meeting from the list or create one."))
    }
}
```

with:

```swift
detail: {
    if let meeting = selectedMeeting {
        MeetingView(meeting: meeting)
    } else {
        ContentUnavailableView("Select a Meeting",
                               systemImage: "clock.badge.questionmark",
                               description: Text("Choose a meeting from the list or create one."))
    }
}
```

- [ ] **Step 2: Replace StackViewHost navigationDestination**

In `StackViewHost.body`, replace:

```swift
.navigationDestination(for: MeetingModel.self) { meeting in
    if meeting.isRunning {
        EditMeetingView(meeting: meeting)
    } else {
        MeetingDetailView(meeting: meeting)
    }
}
```

with:

```swift
.navigationDestination(for: MeetingModel.self) { meeting in
    MeetingView(meeting: meeting)
}
```

- [ ] **Step 3: Verify final RootView.swift looks like this**

```swift
// MeetClock02/Views/RootView.swift

import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            SplitViewHost()
        } else {
            StackViewHost()
        }
    }
}

// MARK: - iPad / macOS

private struct SplitViewHost: View {
    @State private var selectedMeeting: MeetingModel?

    var body: some View {
        NavigationSplitView {
            MeetingListView(selectedMeeting: $selectedMeeting)
        } detail: {
            if let meeting = selectedMeeting {
                MeetingView(meeting: meeting)
            } else {
                ContentUnavailableView("Select a Meeting",
                                       systemImage: "clock.badge.questionmark",
                                       description: Text("Choose a meeting from the list or create one."))
            }
        }
    }
}

// MARK: - iPhone

private struct StackViewHost: View {
    @State private var path = [MeetingModel]()

    var body: some View {
        NavigationStack(path: $path) {
            MeetingListView(path: $path)
                .navigationDestination(for: MeetingModel.self) { meeting in
                    MeetingView(meeting: meeting)
                }
        }
    }
}

#Preview {
    RootView()
}
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add MeetClock02/Views/RootView.swift
git commit -m "refactor: route all meeting navigation through MeetingView"
```

---

### Task 3: Delete EditMeetingView.swift and clean up project

Remove `EditMeetingView.swift` from disk and from the Xcode project file. `MeetingDetailView.swift` stays (it now holds `MeetingView`) — do not delete it.

**Files:**
- Delete from disk: `MeetClock02/Views/MeetingView/EditMeetingView.swift`
- Modify: `MeetClock02.xcodeproj/project.pbxproj` (remove all references to `EditMeetingView.swift`)

- [ ] **Step 1: Delete EditMeetingView.swift from disk**

```bash
rm MeetClock02/Views/MeetingView/EditMeetingView.swift
```

- [ ] **Step 2: Remove EditMeetingView.swift references from project.pbxproj**

Open `MeetClock02.xcodeproj/project.pbxproj` and remove every line that contains `EditMeetingView`. There will be three kinds of entries:

1. A `PBXFileReference` line (defines the file): looks like  
   `XXXX /* EditMeetingView.swift */ = {isa = PBXFileReference; ... path = EditMeetingView.swift; ... };`

2. A `PBXBuildFile` line (adds it to the compile sources): looks like  
   `YYYY /* EditMeetingView.swift in Sources */ = {isa = PBXBuildFile; fileRef = XXXX /* EditMeetingView.swift */; };`

3. A reference inside `PBXGroup` children array: looks like  
   `XXXX /* EditMeetingView.swift */,`

4. A reference inside `PBXSourcesBuildPhase` files array: looks like  
   `YYYY /* EditMeetingView.swift in Sources */,`

Remove all four. Use Read to inspect the file, then Edit to remove the matching lines. After removing, verify no `EditMeetingView` strings remain:

```bash
grep -c "EditMeetingView" MeetClock02.xcodeproj/project.pbxproj
```

Expected: `0`

- [ ] **Step 3: Build to verify clean state**

```bash
xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

If you see `error: build input file cannot be found`, a pbxproj reference to `EditMeetingView.swift` was missed — re-read the pbxproj and remove remaining references.

- [ ] **Step 4: Run unit tests**

```bash
xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MeetClock02Tests test 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` — all model tests (cost calculation, timer, resource validation, rate normalisation) should pass unchanged since no model code was touched.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: delete EditMeetingView — absorbed into MeetingView"
```
