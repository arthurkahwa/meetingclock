// MeetClock02/Views/MeetingListView.swift

import SwiftUI
import SwiftData

// MARK: - Container (owns search/sort state)

struct MeetingListView: View {
    @Environment(\.modelContext) private var modelContext

    var selectedMeeting: Binding<MeetingModel?>?
    var path: Binding<NavigationPath>?

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
                    .accessibilityLabel("Sort meetings")
                }
                ToolbarItemGroup {
                    Button("Add Meeting", systemImage: "plus", action: addMeeting)
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("Creates a new untitled meeting and opens it")
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
    var path: Binding<NavigationPath>?
    var onDelete: (IndexSet, [MeetingModel]) -> Void

    init(searchString: String,
         sortOrder: [SortDescriptor<MeetingModel>],
         selectedMeeting: Binding<MeetingModel?>?,
         path: Binding<NavigationPath>?,
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rowAccessibilityLabel: String {
        let name = meeting.meetingName.isEmpty ? String(localized: "Untitled meeting") : meeting.meetingName
        if meeting.isRunning {
            let cost = meetingLiveCost(meeting, using: exchangeRateService)
            let formatted = cost.formatted(.currency(code: meeting.meetingCurrencyCode))
            return String(format: String(localized: "%@, running, current cost %@"), name, formatted)
        }
        return name
    }

    var body: some View {
        if meeting.isRunning {
            TimelineView(.periodic(from: meeting.meetingStart, by: 1)) { _ in
                rowContent
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rowAccessibilityLabel)
            .accessibilityHint("Double tap to view running meeting")
        } else {
            rowContent
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rowAccessibilityLabel)
                .accessibilityHint("Double tap to open meeting")
        }
    }

    private var rowContent: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(meeting.meetingName.isEmpty ? "Untitled" : meeting.meetingName)
                    .font(meeting.isRunning ? .caption : .headline)
                    .foregroundStyle(meeting.isRunning ? .secondary : .primary)
                if meeting.isRunning {
                    liveCostText
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
            Spacer()
            if meeting.isRunning {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                    .accessibilityHidden(true)
                    .symbolEffect(.pulse, isActive: !reduceMotion)
            }
        }
    }

    private var liveCostText: some View {
        let cost = meetingLiveCost(meeting, using: exchangeRateService)
        return Text(cost, format: .currency(code: meeting.meetingCurrencyCode))
            .contentTransition(.numericText())
    }
}

// MARK: - Cost helpers

/// Per-currency breakdown (retained for legacy use in MeetingLiveBoardView).
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
