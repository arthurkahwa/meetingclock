# Meeting Currency, Navigation & Participant UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-meeting currency with live exchange-rate conversion, fix iPhone row navigation (running → EditMeetingView, non-running → MeetingDetailView), and improve participant creation flow with conditional name fields.

**Architecture:** A new `@Observable ExchangeRateService` is injected app-wide via `.environment`. `MeetingModel` gains `meetingCurrencyCode`. All live-cost displays convert participant rates to the meeting currency using the service. Navigation is restructured so row taps work on iPhone and route to the correct view based on `isRunning`. Participant creation navigates inline within the picker sheet.

**Tech Stack:** SwiftUI, SwiftData, Swift Concurrency (`async/await`), `open.er-api.com` free exchange rate API, iOS 26.2+

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `MeetClock02/Services/ExchangeRateService.swift` | **Create** | Observable exchange rate cache + conversion helper |
| `MeetClock02/Models/MeetingModel.swift` | **Modify** | Add `meetingCurrencyCode`; update `endMeeting()` |
| `MeetClock02/App/MeetClock02App.swift` | **Modify** | Create + inject `ExchangeRateService`; trigger initial fetch |
| `MeetClock02/Views/MeetingView/EditMeetingView.swift` | **Modify** | Add currency picker for `meetingCurrencyCode` |
| `MeetClock02/Views/MeetingView/MeetingRunView.swift` | **Modify** | Use meeting currency for cost display; pass conversion to `endMeeting` |
| `MeetClock02/Views/MeetingView/MeetingDetailView.swift` | **Modify** | Show participant rates converted to meeting currency |
| `MeetClock02/Views/MeetingListView.swift` | **Modify** | Fix row navigation for iPhone; show cost in meeting currency |
| `MeetClock02/Views/RootView.swift` | **Modify** | Branch detail/destination on `meeting.isRunning` |
| `MeetClock02/Views/MeetingParticipantView/ParticipantPickerView.swift` | **Modify** | Navigate to `EditMeetingParticipantView` inline on create |
| `MeetClock02/Views/MeetingParticipantView/EditMeetingParticipantView.swift` | **Modify** | Conditional name fields based on `participantType` |

---

## Task 1: Create ExchangeRateService

**Files:**
- Create: `MeetClock02/Services/ExchangeRateService.swift`

- [ ] **Step 1: Create the Services directory and file**

```swift
// MeetClock02/Services/ExchangeRateService.swift

import Foundation
import Observation

private struct ExchangeRateResponse: Decodable {
    let rates: [String: Double]
}

@Observable
final class ExchangeRateService {
    var rates: [String: Double] = [:]   // all rates relative to USD
    var isLoading = false

    // Convert `amount` from one ISO currency to another.
    // Falls back to 1:1 if rates are unavailable or currency not found.
    func convert(_ amount: Double, from fromCode: String, to toCode: String) -> Double {
        guard fromCode != toCode else { return amount }
        guard let fromRate = rates[fromCode], let toRate = rates[toCode],
              fromRate > 0 else { return amount }
        // rates["EUR"] = 0.92  ⟹  1 USD = 0.92 EUR
        // convert X EUR → GBP = X * rates["GBP"] / rates["EUR"]
        return amount * toRate / fromRate
    }

    func fetchRates() async {
        isLoading = true
        defer { isLoading = false }
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            rates = decoded.rates
        } catch {
            // Keep existing rates on failure; silent degradation.
        }
    }
}
```

- [ ] **Step 2: Build the project to confirm the file compiles**

Run: `xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MeetClock02/Services/ExchangeRateService.swift
git commit -m "feat: add ExchangeRateService with USD-based live exchange rates"
```

---

## Task 2: Add meetingCurrencyCode to MeetingModel

**Files:**
- Modify: `MeetClock02/Models/MeetingModel.swift`

- [ ] **Step 1: Add the property and update init + endMeeting**

Replace the entire file content with:

```swift
// MeetClock02/Models/MeetingModel.swift

import SwiftData
import Foundation

@Model
final class MeetingModel {
    var meetingName: String = ""
    var meetingStart: Date = Date.now
    var meetingEnd: Date = Date.now
    var meetingLength: TimeInterval = 0
    var meetingCost: Double = 0.0
    var meetingNotes: String = ""
    var isRunning: Bool = false
    var pausedAt: Date? = nil
    var totalPausedDuration: TimeInterval = 0
    var meetingCurrencyCode: String = Locale.current.currency?.identifier ?? "USD"

    @Relationship(deleteRule: .nullify, inverse: \MeetingParticipant.meetings)
    var participants: [MeetingParticipant] = []

    init(meetingName: String,
         meetingStart: Date = .now,
         meetingEnd: Date = .now,
         meetingLength: TimeInterval = 0,
         meetingCost: Double = 0,
         meetingNotes: String = "",
         meetingCurrencyCode: String = Locale.current.currency?.identifier ?? "USD",
         participants: [MeetingParticipant] = []) {
        self.meetingName = meetingName
        self.meetingStart = meetingStart
        self.meetingEnd = meetingEnd
        self.meetingLength = meetingLength
        self.meetingCost = meetingCost
        self.meetingNotes = meetingNotes
        self.meetingCurrencyCode = meetingCurrencyCode
        self.participants = participants
    }

    // Elapsed seconds, live. Returns frozen meetingLength when not running.
    var liveElapsed: TimeInterval {
        guard isRunning else { return meetingLength }
        let pauseOffset = pausedAt.map { Date.now.timeIntervalSince($0) } ?? 0
        return Date.now.timeIntervalSince(meetingStart) - totalPausedDuration - pauseOffset
    }

    // convert: (amount, participantCurrencyCode) -> Double in meetingCurrencyCode
    // Default closure is 1:1 (no conversion) for callers without a service.
    func endMeeting(convert: (Double, String) -> Double = { amount, _ in amount }) {
        meetingEnd = .now
        meetingLength = meetingEnd.timeIntervalSince(meetingStart) - totalPausedDuration
        meetingCost = participants.reduce(0.0) { total, p in
            let contribution = meetingLength * p.hourlyRate / 3600
            return total + convert(contribution, p.currencyCode)
        }
        isRunning = false
        pausedAt = nil
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MeetClock02/Models/MeetingModel.swift
git commit -m "feat: add meetingCurrencyCode to MeetingModel; update endMeeting to accept conversion closure"
```

---

## Task 3: Inject ExchangeRateService from MeetClock02App

**Files:**
- Modify: `MeetClock02/App/MeetClock02App.swift`

- [ ] **Step 1: Update the app entry point**

Replace the file content with:

```swift
// MeetClock02/App/MeetClock02App.swift

import SwiftUI
import SwiftData

@main
struct MeetClock02App: App {
    @State private var exchangeRateService = ExchangeRateService()

    let modelContainer: ModelContainer = {
        let schema = Schema([MeetingModel.self, MeetingParticipant.self])
        let isUITesting = CommandLine.arguments.contains("--uitesting")
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
                .environment(exchangeRateService)
                .task { await exchangeRateService.fetchRates() }
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MeetClock02/App/MeetClock02App.swift
git commit -m "feat: inject ExchangeRateService into environment and fetch rates on launch"
```

---

## Task 4: Add currency picker to EditMeetingView

**Files:**
- Modify: `MeetClock02/Views/MeetingView/EditMeetingView.swift`

- [ ] **Step 1: Add the currency section**

Replace the file content with:

```swift
// MeetClock02/Views/MeetingView/EditMeetingView.swift

import SwiftUI
import SwiftData

struct EditMeetingView: View {
    @Bindable var meeting: MeetingModel

    @Query(sort: [
        SortDescriptor(\MeetingParticipant.lastName),
        SortDescriptor(\MeetingParticipant.firstName),
        SortDescriptor(\MeetingParticipant.hourlyRate)
    ]) var participants: [MeetingParticipant]

    var body: some View {
        Form {
            Section {
                TextField("Meeting Name", text: $meeting.meetingName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.never)

                DatePicker("Start", selection: $meeting.meetingStart,
                           displayedComponents: [.date, .hourAndMinute])

                DatePicker("End", selection: $meeting.meetingEnd,
                           displayedComponents: [.date, .hourAndMinute])
            }

            Section("Currency") {
                Picker("Meeting Currency", selection: $meeting.meetingCurrencyCode) {
                    ForEach(Locale.commonISOCurrencyCodes, id: \.self) { code in
                        Text("\(code) – \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
                            .tag(code)
                    }
                }
            }

            Section("Notes") {
                TextField("Notes", text: $meeting.meetingNotes, axis: .vertical)
            }
        }
        .navigationTitle("Edit Meeting")
        .navigationBarTitleDisplayMode(.inline)
    }

    func addParticipant() {}
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MeetClock02/Views/MeetingView/EditMeetingView.swift
git commit -m "feat: add meeting currency picker to EditMeetingView"
```

---

## Task 5: Update MeetingRunView to use meeting currency

**Files:**
- Modify: `MeetClock02/Views/MeetingView/MeetingRunView.swift`

- [ ] **Step 1: Replace cost display and stop button to use ExchangeRateService**

Replace the file content with:

```swift
// MeetClock02/Views/MeetingView/MeetingRunView.swift

import SwiftUI

struct MeetingRunView: View {
    @Bindable var meeting: MeetingModel
    @Environment(ExchangeRateService.self) private var exchangeRateService

    var body: some View {
        TimelineView(.periodic(from: meeting.meetingStart, by: 1)) { _ in
            VStack(spacing: 16) {
                // Elapsed time
                Text(Duration.seconds(meeting.liveElapsed),
                     format: .time(pattern: .hourMinuteSecond))
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.primary)

                // Total live cost in meeting currency
                let liveCost = meetingLiveCost(meeting, using: exchangeRateService)
                if meeting.participants.isEmpty {
                    Text("No participants")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.secondary)
                } else {
                    Text(liveCost, format: .currency(code: meeting.meetingCurrencyCode))
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }

                // Controls
                HStack(spacing: 24) {
                    if !meeting.isRunning && meeting.pausedAt == nil && meeting.meetingLength == 0 {
                        startButton
                    } else if meeting.isRunning && meeting.pausedAt == nil {
                        pauseButton
                        stopButton
                    } else if meeting.pausedAt != nil {
                        resumeButton
                        stopButton
                    }
                }
            }
        }
    }

    // MARK: - Buttons

    private var startButton: some View {
        Button {
            meeting.meetingStart = .now
            meeting.totalPausedDuration = 0
            meeting.pausedAt = nil
            meeting.isRunning = true
        } label: {
            Label("Start", systemImage: "play.fill")
                .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .accessibilityIdentifier("Start")
    }

    private var pauseButton: some View {
        Button {
            meeting.pausedAt = .now
        } label: {
            Label("Pause", systemImage: "pause.fill")
                .font(.headline)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("Pause")
    }

    private var resumeButton: some View {
        Button {
            if let pausedAt = meeting.pausedAt {
                meeting.totalPausedDuration += Date.now.timeIntervalSince(pausedAt)
            }
            meeting.pausedAt = nil
        } label: {
            Label("Resume", systemImage: "play.fill")
                .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .accessibilityIdentifier("Resume")
    }

    private var stopButton: some View {
        Button {
            let service = exchangeRateService
            let toCurrency = meeting.meetingCurrencyCode
            meeting.endMeeting { amount, fromCurrency in
                service.convert(amount, from: fromCurrency, to: toCurrency)
            }
        } label: {
            Label("Stop", systemImage: "stop.fill")
                .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .accessibilityIdentifier("Stop")
    }
}
```

- [ ] **Step 2: Add `meetingLiveCost` helper to MeetingListView.swift**

Open `MeetClock02/Views/MeetingListView.swift`. After the existing `groupedLiveCosts` function, add:

```swift
/// Total live cost for a meeting, converted to the meeting's own currency.
func meetingLiveCost(_ meeting: MeetingModel, using service: ExchangeRateService) -> Double {
    let elapsed = meeting.liveElapsed
    return meeting.participants.reduce(0.0) { total, p in
        let contribution = elapsed * p.hourlyRate / 3600
        return total + service.convert(contribution, from: p.currencyCode, to: meeting.meetingCurrencyCode)
    }
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add MeetClock02/Views/MeetingView/MeetingRunView.swift MeetClock02/Views/MeetingListView.swift
git commit -m "feat: display meeting cost in meeting currency using live exchange rates"
```

---

## Task 6: Show participant rates in meeting currency in MeetingDetailView

**Files:**
- Modify: `MeetClock02/Views/MeetingView/MeetingDetailView.swift`

- [ ] **Step 1: Update ParticipantRowView to show rate in meeting currency**

Replace the file content with:

```swift
// MeetClock02/Views/MeetingView/MeetingDetailView.swift

import SwiftUI
import SwiftData

struct MeetingDetailView: View {
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
            fullDetail
        }
        #else
        fullDetail
        #endif
    }

    private var fullDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MeetingRunView(meeting: meeting)
                    .padding(.horizontal)

                Divider()

                participantSection
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(meeting.meetingName.isEmpty ? "Meeting" : meeting.meetingName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Add Participant", systemImage: "person.badge.plus") {
                    showingPicker = true
                }
                NavigationLink(destination: EditMeetingView(meeting: meeting)) {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            ParticipantPickerView(meeting: meeting)
        }
    }

    private var participantSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Participants")
                .font(.headline)

            if meeting.participants.isEmpty {
                Text("No participants yet")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(meeting.participants) { participant in
                    NavigationLink(destination: EditMeetingParticipantView(participant: participant)) {
                        ParticipantRowView(
                            participant: participant,
                            meetingCurrency: meeting.meetingCurrencyCode,
                            exchangeRateService: exchangeRateService
                        )
                    }
                }
            }
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

                // Show rate converted to meeting currency
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

- [ ] **Step 2: Build**

Run: `xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MeetClock02/Views/MeetingView/MeetingDetailView.swift
git commit -m "feat: show participant rates converted to meeting currency in detail view"
```

---

## Task 7: Fix row navigation and update MeetingListView live cost

**Files:**
- Modify: `MeetClock02/Views/MeetingListView.swift`

The current `List(selection: selectedMeeting)` + `.tag()` pattern only works for `NavigationSplitView` (iPad). On iPhone (`NavigationStack`), rows have no tap-navigation. Fix: for the iPhone path, each row gets a `Button` that appends to `path`. Also update `MeetingRowView` to use meeting currency for its live cost ticker.

- [ ] **Step 1: Replace MeetingListView.swift content**

```swift
// MeetClock02/Views/MeetingListView.swift

import SwiftUI
import SwiftData

// MARK: - Container (owns search/sort state)

struct MeetingListView: View {
    @Environment(\.modelContext) private var modelContext

    var selectedMeeting: Binding<MeetingModel?>?
    var path: Binding<[MeetingModel]>?

    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\MeetingModel.meetingName)]

    var body: some View {
        MeetingQueryList(searchString: searchText,
                         sortOrder: sortOrder,
                         selectedMeeting: selectedMeeting,
                         path: path,
                         onDelete: deleteMeetings)
            .navigationTitle("Meetings")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItemGroup {
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort", selection: $sortOrder) {
                            Text("Name (A – Z)")
                                .tag([SortDescriptor(\MeetingModel.meetingName)])
                            Text("Name (Z – A)")
                                .tag([SortDescriptor(\MeetingModel.meetingName, order: .reverse)])
                        }
                    }
                }
                ToolbarItemGroup {
                    Button("Add Meeting", systemImage: "plus", action: addMeeting)
                        .buttonStyle(.borderedProminent)
                }
            }
    }

    private func addMeeting() {
        let meeting = MeetingModel(meetingName: "New Meeting")
        modelContext.insert(meeting)
        if let path {
            path.wrappedValue.append(meeting)
        } else {
            selectedMeeting?.wrappedValue = meeting
        }
    }

    private func deleteMeetings(at offsets: IndexSet, from meetings: [MeetingModel]) {
        offsets.forEach { modelContext.delete(meetings[$0]) }
    }
}

// MARK: - Query list

private struct MeetingQueryList: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ExchangeRateService.self) private var exchangeRateService
    @Query private var meetings: [MeetingModel]

    var selectedMeeting: Binding<MeetingModel?>?
    var path: Binding<[MeetingModel]>?
    var onDelete: (IndexSet, [MeetingModel]) -> Void

    init(searchString: String,
         sortOrder: [SortDescriptor<MeetingModel>],
         selectedMeeting: Binding<MeetingModel?>?,
         path: Binding<[MeetingModel]>?,
         onDelete: @escaping (IndexSet, [MeetingModel]) -> Void) {
        _meetings = Query(filter: #Predicate { meeting in
            searchString.isEmpty
            || meeting.meetingName.localizedStandardContains(searchString)
            || meeting.meetingNotes.localizedStandardContains(searchString)
        }, sort: sortOrder)
        self.selectedMeeting = selectedMeeting
        self.path = path
        self.onDelete = onDelete
    }

    var body: some View {
        List(selection: selectedMeeting) {
            ForEach(meetings) { meeting in
                rowView(for: meeting)
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            if let idx = meetings.firstIndex(where: {
                                $0.persistentModelID == meeting.persistentModelID
                            }) {
                                onDelete(IndexSet(integer: idx), meetings)
                            }
                        }
                    }
            }
            .onDelete { onDelete($0, meetings) }
        }
        .navigationTitle("Meetings: \(meetings.count)")
    }

    @ViewBuilder
    private func rowView(for meeting: MeetingModel) -> some View {
        if let pathBinding = path {
            // iPhone / NavigationStack: tap pushes to path
            Button {
                pathBinding.wrappedValue.append(meeting)
            } label: {
                MeetingRowView(meeting: meeting, exchangeRateService: exchangeRateService)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            // iPad / NavigationSplitView: List(selection:) + .tag() handles navigation
            MeetingRowView(meeting: meeting, exchangeRateService: exchangeRateService)
                .tag(meeting)
        }
    }
}

// MARK: - Row

struct MeetingRowView: View {
    let meeting: MeetingModel
    let exchangeRateService: ExchangeRateService

    var body: some View {
        if meeting.isRunning {
            TimelineView(.periodic(from: meeting.meetingStart, by: 1)) { _ in
                rowContent
            }
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(meeting.meetingName.isEmpty ? "Untitled" : meeting.meetingName)
                    .font(.headline)
                if meeting.isRunning {
                    liveCostText
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if meeting.isRunning {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse)
                    .font(.caption)
            }
        }
    }

    private var liveCostText: some View {
        let cost = meetingLiveCost(meeting, using: exchangeRateService)
        return Text(cost, format: .currency(code: meeting.meetingCurrencyCode))
    }
}

// MARK: - Cost helpers

/// Per-currency breakdown (legacy — retained for MeetingLiveBoardView).
func groupedLiveCosts(_ meeting: MeetingModel) -> [(currency: String, cost: Double)] {
    let elapsed = meeting.liveElapsed
    let grouped = Dictionary(grouping: meeting.participants, by: \.currencyCode)
    return grouped
        .map { currency, participants in
            let total = participants.reduce(0) { $0 + $1.hourlyRate }
            return (currency: currency, cost: elapsed * total / 3600)
        }
        .sorted { $0.currency < $1.currency }
}

/// Total live cost converted to the meeting's own currency.
func meetingLiveCost(_ meeting: MeetingModel, using service: ExchangeRateService) -> Double {
    let elapsed = meeting.liveElapsed
    return meeting.participants.reduce(0.0) { total, p in
        let contribution = elapsed * p.hourlyRate / 3600
        return total + service.convert(contribution, from: p.currencyCode, to: meeting.meetingCurrencyCode)
    }
}

#Preview {
    MeetingListView()
}
```

> **Note:** `MeetingRowView` now takes `exchangeRateService` as a parameter instead of reading from environment — this avoids a second `@Environment` lookup inside a `TimelineView`. The `MeetingQueryList` passes it down explicitly.

- [ ] **Step 2: Fix `meetingLiveCost` duplicate now that it's in MeetingListView.swift**

Open `MeetClock02/Views/MeetingView/MeetingRunView.swift`. The `meetingLiveCost` function was added to `MeetingListView.swift` in Task 5, Step 2. Check if it was added there and remove the duplicate if present. The function now lives in `MeetingListView.swift` which is part of the same module, so `MeetingRunView.swift` can call it directly without re-declaring it.

- [ ] **Step 3: Build**

Run: `xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add MeetClock02/Views/MeetingListView.swift MeetClock02/Views/MeetingView/MeetingRunView.swift
git commit -m "feat: fix iPhone row navigation; show live cost in meeting currency in list rows"
```

---

## Task 8: Route navigation destination based on isRunning

**Files:**
- Modify: `MeetClock02/Views/RootView.swift`

- [ ] **Step 1: Update StackViewHost and SplitViewHost**

Replace the file content with:

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
    }
}

// MARK: - iPhone

private struct StackViewHost: View {
    @State private var path = [MeetingModel]()

    var body: some View {
        NavigationStack(path: $path) {
            MeetingListView(path: $path)
                .navigationDestination(for: MeetingModel.self) { meeting in
                    if meeting.isRunning {
                        EditMeetingView(meeting: meeting)
                    } else {
                        MeetingDetailView(meeting: meeting)
                    }
                }
        }
    }
}

#Preview {
    RootView()
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MeetClock02/Views/RootView.swift
git commit -m "feat: route meeting row navigation to EditMeetingView when running, DetailView otherwise"
```

---

## Task 9: Navigate to EditMeetingParticipantView inline in ParticipantPickerView

**Files:**
- Modify: `MeetClock02/Views/MeetingParticipantView/ParticipantPickerView.swift`

- [ ] **Step 1: Replace createAndAdd with inline navigation**

Replace the file content with:

```swift
// MeetClock02/Views/MeetingParticipantView/ParticipantPickerView.swift

import SwiftUI
import SwiftData

struct ParticipantPickerView: View {
    @Bindable var meeting: MeetingModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\MeetingParticipant.lastName),
                  SortDescriptor(\MeetingParticipant.firstName)])
    private var allParticipants: [MeetingParticipant]

    @State private var searchText = ""
    @State private var resourceConflictAlert = false
    @State private var conflictingParticipant: MeetingParticipant?
    @State private var newParticipant: MeetingParticipant?

    var filteredParticipants: [MeetingParticipant] {
        guard !searchText.isEmpty else { return allParticipants }
        return allParticipants.filter {
            $0.firstName.localizedStandardContains(searchText) ||
            $0.lastName.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        createAndNavigate()
                    } label: {
                        Label("New Participant", systemImage: "person.badge.plus")
                    }
                    .accessibilityIdentifier("New Participant")
                }

                Section("All Participants") {
                    ForEach(filteredParticipants) { participant in
                        participantRow(participant)
                    }
                }
            }
            .navigationTitle("Add Participant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(text: $searchText)
            .navigationDestination(item: $newParticipant) { participant in
                EditMeetingParticipantView(participant: participant)
            }
            .alert("Resource Unavailable",
                   isPresented: $resourceConflictAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(conflictingParticipant.map { "\($0.firstName) \($0.lastName)" } ?? "This resource") is already in another running meeting.")
            }
        }
    }

    // MARK: - Row

    private func participantRow(_ participant: MeetingParticipant) -> some View {
        let isInMeeting = meeting.participants.contains {
            $0.persistentModelID == participant.persistentModelID
        }
        let name = participant.participantType == .resource
            ? participant.firstName
            : "\(participant.firstName) \(participant.lastName)"
        return HStack {
            Image(systemName: participant.participantType == .human ? "person.fill" : "desktopcomputer")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text(name)
                Text(participant.participantType == .human ? "Human" : "Resource")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isInMeeting {
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggle(participant, isInMeeting: isInMeeting)
        }
    }

    // MARK: - Actions

    private func toggle(_ participant: MeetingParticipant, isInMeeting: Bool) {
        if isInMeeting {
            meeting.participants.removeAll {
                $0.persistentModelID == participant.persistentModelID
            }
        } else {
            do {
                if try meeting.canAdd(participant) {
                    meeting.participants.append(participant)
                } else {
                    conflictingParticipant = participant
                    resourceConflictAlert = true
                }
            } catch {
                conflictingParticipant = participant
                resourceConflictAlert = true
            }
        }
    }

    private func createAndNavigate() {
        let participant = MeetingParticipant(firstName: "", lastName: "", hourlyRate: 0)
        modelContext.insert(participant)
        meeting.participants.append(participant)
        newParticipant = participant
    }
}
```

> **Key change:** `navigationDestination(item: $newParticipant)` pushes `EditMeetingParticipantView` within the sheet's own `NavigationStack` when `newParticipant` is set. Setting `newParticipant = nil` (back button) returns to the picker without dismissing the sheet.

- [ ] **Step 2: Build**

Run: `xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MeetClock02/Views/MeetingParticipantView/ParticipantPickerView.swift
git commit -m "feat: navigate to EditMeetingParticipantView inline on create, no sheet dismissal"
```

---

## Task 10: Conditional name fields in EditMeetingParticipantView

**Files:**
- Modify: `MeetClock02/Views/MeetingParticipantView/EditMeetingParticipantView.swift`

- [ ] **Step 1: Move type picker above identity; add conditional name fields**

Replace the file content with:

```swift
// MeetClock02/Views/MeetingParticipantView/EditMeetingParticipantView.swift

import SwiftUI

struct EditMeetingParticipantView: View {
    @Bindable var participant: MeetingParticipant

    @State private var inputRate: Double

    init(participant: MeetingParticipant) {
        self.participant = participant
        let displayRate = participant.rateType == .daily
            ? participant.hourlyRate * 8
            : participant.hourlyRate
        _inputRate = State(initialValue: displayRate)
    }

    var body: some View {
        Form {
            Section("Type") {
                Picker("Participant Type", selection: $participant.participantType) {
                    ForEach(ParticipantType.allCases, id: \.self) { type in
                        Text(type == .human ? "Human" : "Resource").tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: participant.participantType) { _, newType in
                    if newType == .resource {
                        participant.lastName = ""
                    }
                }
            }

            Section("Identity") {
                if participant.participantType == .human {
                    TextField("First Name", text: $participant.firstName)
                        .accessibilityIdentifier("First Name")
                    TextField("Last Name", text: $participant.lastName)
                        .accessibilityIdentifier("Last Name")
                } else {
                    TextField("Name", text: $participant.firstName)
                        .accessibilityIdentifier("Name")
                }
            }

            Section("Rate") {
                Picker("Rate Type", selection: $participant.rateType) {
                    Text("Hourly").tag(RateType.hourly)
                    Text("Daily").tag(RateType.daily)
                }
                .pickerStyle(.segmented)
                .onChange(of: participant.rateType) { _, newType in
                    inputRate = newType == .daily
                        ? participant.hourlyRate * 8
                        : participant.hourlyRate
                }

                HStack {
                    Text(participant.rateType == .daily ? "Daily Rate" : "Hourly Rate")
                    Spacer()
                    TextField("Rate", value: $inputRate, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: inputRate) { _, newValue in
                            participant.hourlyRate = participant.rateType.normalizedHourlyRate(from: newValue)
                        }
                }

                Picker("Currency", selection: $participant.currencyCode) {
                    ForEach(Locale.commonISOCurrencyCodes, id: \.self) { code in
                        Text("\(code) – \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
                            .tag(code)
                    }
                }
            }
        }
        .navigationTitle(participant.participantType == .resource
            ? (participant.firstName.isEmpty ? "New Resource" : participant.firstName)
            : (participant.firstName.isEmpty ? "New Participant" : participant.firstName))
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MeetClock02/Views/MeetingParticipantView/EditMeetingParticipantView.swift
git commit -m "feat: conditional name fields — first+last for human, single name for resource"
```

---

## Task 11: Update MeetingLiveBoardView to use meeting currency

**Files:**
- Modify: `MeetClock02/Views/MeetingView/MeetingLiveBoardView.swift`

`MeetingLiveBoardView` is the landscape-iPhone full-screen cost display. It currently calls `groupedLiveCosts` which shows per-participant-currency breakdown. It must show a single total in the meeting currency, consistent with `MeetingRunView`.

- [ ] **Step 1: Update MeetingLiveBoardView**

Replace the file content with:

```swift
// MeetClock02/Views/MeetingView/MeetingLiveBoardView.swift

#if os(iOS)
import SwiftUI

struct MeetingLiveBoardView: View {
    let meeting: MeetingModel
    @Environment(ExchangeRateService.self) private var exchangeRateService

    var body: some View {
        TimelineView(.periodic(from: meeting.meetingStart, by: 1)) { _ in
            GeometryReader { geo in
                VStack(spacing: 8) {
                    Text(Duration.seconds(meeting.liveElapsed),
                         format: .time(pattern: .hourMinuteSecond))
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(.secondary)

                    let liveCost = meetingLiveCost(meeting, using: exchangeRateService)
                    if meeting.participants.isEmpty {
                        Text("No participants")
                            .font(.system(size: geo.size.height * 0.25))
                            .minimumScaleFactor(0.1)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(liveCost, format: .currency(code: meeting.meetingCurrencyCode))
                            .font(.system(size: geo.size.height * 0.35))
                            .minimumScaleFactor(0.1)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .background(.background)
    }
}
#endif
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MeetClock02/Views/MeetingView/MeetingLiveBoardView.swift
git commit -m "feat: show meeting currency cost in landscape live board view"
```

---

## Task 12: Final build and smoke test

- [ ] **Step 1: Verify no duplicate `meetingLiveCost` symbol**

Run: `grep -rn "func meetingLiveCost" MeetClock02/`
Expected: exactly one match in `MeetClock02/Views/MeetingListView.swift`.
If a second match exists anywhere, delete that declaration (the caller just uses it, not re-declares it).

- [ ] **Step 2: Full build**

Run: `xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 build 2>&1 | tail -10`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Run unit tests**

Run: `xcodebuild -project MeetClock02.xcodeproj -scheme MeetClock02 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MeetClock02Tests test 2>&1 | tail -10`
Expected: tests pass (or report which tests need updating due to model changes)

- [ ] **Step 4: Final commit if any fixes applied**

```bash
git add -p
git commit -m "fix: resolve any build issues from integration"
```
