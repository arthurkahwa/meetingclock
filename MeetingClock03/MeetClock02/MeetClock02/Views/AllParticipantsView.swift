// MeetClock02/Views/AllParticipantsView.swift

import SwiftUI
import SwiftData

struct AllParticipantsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MeetingParticipant.firstName) private var participants: [MeetingParticipant]
    @Binding var path: [MeetingParticipant]
    @State private var searchText = ""

    private var filtered: [MeetingParticipant] {
        guard !searchText.isEmpty else { return participants }
        return participants.filter {
            $0.firstName.localizedCaseInsensitiveContains(searchText) ||
            $0.lastName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if participants.isEmpty {
                ContentUnavailableView("No Participants",
                                       systemImage: "person.slash",
                                       description: Text("Add participants to track meeting costs."))
            } else {
                List {
                    ForEach(filtered) { participant in
                        NavigationLink(value: participant) {
                            ParticipantRow(participant: participant)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Participants")
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {
                    let p = MeetingParticipant(
                        firstName: "",
                        lastName: "",
                        hourlyRate: 0,
                        rateType: .hourly,
                        participantType: .human,
                        currencyCode: Locale.current.currency?.identifier ?? "USD"
                    )
                    modelContext.insert(p)
                    path.append(p)
                }
                .accessibilityHint("Creates a new participant")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filtered[index])
        }
    }
}

private struct ParticipantRow: View {
    let participant: MeetingParticipant

    private var displayName: String {
        participant.participantType == .resource
            ? participant.firstName
            : "\(participant.firstName) \(participant.lastName)".trimmingCharacters(in: .whitespaces)
    }

    private var rateLabel: String {
        if participant.rateType == .daily {
            let daily = participant.hourlyRate * 8
            return "\(daily.formatted(.currency(code: participant.currencyCode)))/day"
        } else {
            return "\(participant.hourlyRate.formatted(.currency(code: participant.currencyCode)))/hr"
        }
    }

    private var rowLabel: String {
        let displayRate = participant.rateType == .daily ? participant.hourlyRate * 8 : participant.hourlyRate
        let formattedRate = displayRate.formatted(.currency(code: participant.currencyCode))
        if participant.participantType == .resource {
            if participant.rateType == .daily {
                return String(format: String(localized: "%@, Resource, %@ per day"), displayName, formattedRate)
            } else {
                return String(format: String(localized: "%@, Resource, %@ per hour"), displayName, formattedRate)
            }
        } else {
            if participant.rateType == .daily {
                return String(format: String(localized: "%@, Person, %@ per day"), displayName, formattedRate)
            } else {
                return String(format: String(localized: "%@, Person, %@ per hour"), displayName, formattedRate)
            }
        }
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName.isEmpty ? "Unnamed" : displayName)
                    .font(.body)
                Text(rateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: participant.participantType == .resource ? "desktopcomputer" : "person.fill")
                .foregroundStyle(.accent)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowLabel)
    }
}
