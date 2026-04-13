// MeetClock02/Views/MeetingView/MeetingRunView.swift

import SwiftUI

struct MeetingRunView: View {
    @Bindable var meeting: MeetingModel
    @Environment(ExchangeRateService.self) private var exchangeRateService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: meeting.meetingStart, by: 1)) { _ in
            VStack(spacing: 16) {
                // Elapsed time
                Text(Duration.seconds(meeting.liveElapsed),
                     format: .time(pattern: .hourMinuteSecond))
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Elapsed time")
                    .accessibilityValue(
                        Duration.seconds(meeting.liveElapsed)
                            .formatted(.time(pattern: .hourMinuteSecond))
                    )

                // Total live cost in meeting currency
                let liveCost = meetingLiveCost(meeting, using: exchangeRateService)
                if meeting.participants.isEmpty {
                    Text("No participants")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("No participants added. Meeting cost will be zero.")
                } else {
                    Text(liveCost, format: .currency(code: meeting.meetingCurrencyCode))
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                        .contentTransition(reduceMotion ? .identity : .numericText())
                        .accessibilityLabel("Current meeting cost")
                        .accessibilityValue(liveCost.formatted(.currency(code: meeting.meetingCurrencyCode)))
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
                    } else {
                        restartButton
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
        .accessibilityHint("Begins the meeting timer from now")
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
        .accessibilityHint("Freezes the timer without ending the meeting")
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
        .accessibilityHint("Continues the timer from where it was paused")
    }

    private var restartButton: some View {
        Button {
            meeting.meetingStart        = .now
            meeting.meetingEnd          = .now
            meeting.meetingLength       = 0
            meeting.meetingCost         = 0
            meeting.totalPausedDuration = 0
            meeting.pausedAt            = nil
            meeting.isRunning           = true
        } label: {
            Label("Restart", systemImage: "arrow.clockwise")
                .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .accessibilityIdentifier("Restart")
        .accessibilityHint("Resets the timer to zero and starts again, keeping all participants")
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
        .accessibilityHint("Ends the meeting and saves the total cost")
    }
}
