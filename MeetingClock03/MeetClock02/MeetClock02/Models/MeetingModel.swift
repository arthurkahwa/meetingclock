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
