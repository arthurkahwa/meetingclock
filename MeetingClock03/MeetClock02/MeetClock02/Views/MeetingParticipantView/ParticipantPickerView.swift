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
                    .accessibilityHint("Creates a new participant and adds them to the meeting")
                }

                Section("All Participants") {
                    ForEach(filteredParticipants) { participant in
                        participantRow(participant)
                    }
                }
            }
            .navigationTitle("Add Participant")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityHint("Closes the participant picker and returns to the meeting")
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

    private func rowLabel(for participant: MeetingParticipant, inMeeting: Bool) -> String {
        let name = participant.participantType == .resource
            ? participant.firstName
            : "\(participant.firstName) \(participant.lastName)".trimmingCharacters(in: .whitespaces)
        let displayName = name.isEmpty ? String(localized: "Unnamed") : name
        if participant.participantType == .resource {
            return String(format: String(localized: inMeeting ? "%@, Resource, In meeting" : "%@, Resource, Not in meeting"), displayName)
        } else {
            return String(format: String(localized: inMeeting ? "%@, Person, In meeting" : "%@, Person, Not in meeting"), displayName)
        }
    }

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
                .accessibilityHidden(true)
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
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggle(participant, isInMeeting: isInMeeting)
        }
        .accessibilityLabel(rowLabel(for: participant, inMeeting: isInMeeting))
        .accessibilityHint(isInMeeting ? "Double tap to remove from meeting" : "Double tap to add to meeting")
        .accessibilityAddTraits(.isButton)
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
