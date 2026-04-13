// MeetClock02/Views/MeetingView/MeetingLiveBoardView.swift

#if os(iOS)
import SwiftData
import SwiftUI

struct MeetingLiveBoardView: View {
    let meeting: MeetingModel
    @Environment(ExchangeRateService.self) private var exchangeRateService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: meeting.meetingStart, by: 1)) { context in
            let now = context.date
            let pauseOffset = meeting.pausedAt.map { now.timeIntervalSince($0) } ?? 0
            let elapsed: TimeInterval = meeting.isRunning
                ? max(0, now.timeIntervalSince(meeting.meetingStart) - meeting.totalPausedDuration - pauseOffset)
                : meeting.meetingLength
            let liveCost = meeting.participants.reduce(0.0) { total, p in
                let contribution = elapsed * p.hourlyRate / 3600
                return total + exchangeRateService.convert(contribution, from: p.currencyCode, to: meeting.meetingCurrencyCode)
            }

            GeometryReader { geo in
                VStack(spacing: 8) {
                    Text(Duration.seconds(elapsed),
                         format: .time(pattern: .hourMinuteSecond))
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Elapsed time")
                        .accessibilityValue(Duration.seconds(elapsed).formatted(.time(pattern: .hourMinuteSecond)))

                    if meeting.participants.isEmpty {
                        Text("No participants")
                            .font(.system(size: geo.size.height * 0.25))
                            .minimumScaleFactor(0.1)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("No participants added. Meeting cost will be zero.")
                    } else {
                        Text(liveCost, format: .currency(code: meeting.meetingCurrencyCode))
                            .font(.system(size: geo.size.height * 0.35))
                            .minimumScaleFactor(0.1)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                            .contentTransition(reduceMotion ? .identity : .numericText())
                            .accessibilityLabel("Current meeting cost")
                            .accessibilityValue(liveCost.formatted(.currency(code: meeting.meetingCurrencyCode)))
                            .padding(.leading)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .background(.background)
    }
}

// MARK: - Previews

#Preview("With Participants") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: MeetingModel.self, configurations: config)

    let alice = MeetingParticipant(firstName: "Alice", lastName: "Smith", hourlyRate: 150, currencyCode: "USD")
    let bob = MeetingParticipant(firstName: "Bob", lastName: "Jones", hourlyRate: 200, currencyCode: "USD")
    container.mainContext.insert(alice)
    container.mainContext.insert(bob)

    let meeting = MeetingModel(
        meetingName: "Sprint Planning",
        meetingStart: Date.now.addingTimeInterval(-600),
        participants: [alice, bob]
    )
    meeting.isRunning = true
    container.mainContext.insert(meeting)

    return MeetingLiveBoardView(meeting: meeting)
        .environment(ExchangeRateService())
        .modelContainer(container)
}

#Preview("No Participants") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: MeetingModel.self, configurations: config)

    let meeting = MeetingModel(
        meetingName: "Empty Meeting",
        meetingStart: Date.now.addingTimeInterval(-300)
    )
    meeting.isRunning = true
    container.mainContext.insert(meeting)

    return MeetingLiveBoardView(meeting: meeting)
        .environment(ExchangeRateService())
        .modelContainer(container)
}
#endif
