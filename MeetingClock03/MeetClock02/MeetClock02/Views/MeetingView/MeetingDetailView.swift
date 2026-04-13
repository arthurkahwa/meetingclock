// MeetClock02/Views/MeetingView/MeetingDetailView.swift — contains MeetingView

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
                    .accessibilityLabel("Meeting name")
                    .accessibilityHint("Enter a name to identify this meeting")

                if meeting.isRunning {
                    LabeledContent("Started") {
                        Text(meeting.meetingStart, style: .time)
                    }
                    .accessibilityLabel("Meeting started at \(meeting.meetingStart.formatted(date: .omitted, time: .shortened))")
                } else {
                    DatePicker("Start", selection: $meeting.meetingStart,
                               displayedComponents: [.date, .hourAndMinute])
                        .accessibilityHint("Meeting start date and time")
                    DatePicker("End", selection: $meeting.meetingEnd,
                               displayedComponents: [.date, .hourAndMinute])
                        .accessibilityHint("Meeting end date and time")
                }

                Picker("Currency", selection: $meeting.meetingCurrencyCode) {
                    ForEach(Locale.commonISOCurrencyCodes, id: \.self) { code in
                        Text("\(code) – \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
                            .tag(code)
                    }
                }
                .accessibilityLabel("Meeting currency")
                .accessibilityHint("All participant costs will be displayed in this currency")

                TextField("Notes", text: $meeting.meetingNotes, axis: .vertical)
                    .accessibilityLabel("Meeting notes")
                    .accessibilityHint("Optional notes about this meeting")
            }

            Section {
                MeetingRunView(meeting: meeting)
            }

            Section("Participants") {
                if meeting.participants.isEmpty {
                    Text("No participants yet")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .accessibilityLabel("No participants added yet. Tap Add Participant to add people or resources.")
                }
                ForEach(meeting.participants) { participant in
                    NavigationLink(value: participant) {
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
                .accessibilityHint("Opens a list of all participants to add to this meeting")
            }
        }
        .navigationTitle(meeting.meetingName.isEmpty ? "Meeting" : meeting.meetingName)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sheet(isPresented: $showingPicker) {
            ParticipantPickerView(meeting: meeting)
        }
        .navigationDestination(for: MeetingParticipant.self) { participant in
            EditMeetingParticipantView(participant: participant)
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
                .accessibilityHidden(true)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(participantAccessibilityLabel)
    }

    private var participantAccessibilityLabel: String {
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

    private var displayName: String {
        participant.participantType == .resource
            ? participant.firstName
            : "\(participant.firstName) \(participant.lastName)"
    }
}
