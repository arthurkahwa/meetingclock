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
                .accessibilityLabel("Participant type")
                .accessibilityHint("Choose Human for people, or Resource for equipment and services")
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
                        .accessibilityHint("Required for identifying this participant")
                    TextField("Last Name", text: $participant.lastName)
                        .accessibilityIdentifier("Last Name")
                        .accessibilityHint("Optional family name")
                } else {
                    TextField("Name", text: $participant.firstName)
                        .accessibilityIdentifier("Name")
                        .accessibilityLabel("Resource name")
                        .accessibilityHint("Name for this resource, for example a meeting room or piece of equipment")
                }
            }

            Section("Rate") {
                Picker("Rate Type", selection: $participant.rateType) {
                    Text("Hourly").tag(RateType.hourly)
                    Text("Daily").tag(RateType.daily)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Rate type")
                .accessibilityHint("Hourly rates bill per hour. Daily rates are divided by 8 to get the hourly equivalent.")
                .onChange(of: participant.rateType) { _, newType in
                    inputRate = newType == .daily
                        ? participant.hourlyRate * 8
                        : participant.hourlyRate
                }

                HStack {
                    Text(participant.rateType == .daily ? "Daily Rate" : "Hourly Rate")
                    Spacer()
                    TextField("Rate", value: $inputRate, format: .number)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel(participant.rateType == .daily ? "Daily rate" : "Hourly rate")
                        .accessibilityHint("Enter a numeric value")
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
                .accessibilityLabel("Participant currency")
                .accessibilityHint("The currency for this participant's billing rate")
            }
        }
        .navigationTitle(participant.participantType == .resource
            ? (participant.firstName.isEmpty ? "New Resource" : participant.firstName)
            : (participant.firstName.isEmpty ? "New Participant" : participant.firstName))
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}
