//
//  MeetClock02Tests.swift
//  MeetClock02Tests
//
//  Created by Arthur Nsereko Kahwa on 2026-02-02.
//

import Testing
import Foundation
import SwiftData
@testable import MeetClock02

// MARK: - Helpers

@MainActor
private func makeContainer() throws -> ModelContainer {
    let schema = Schema([MeetingModel.self, MeetingParticipant.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}

// MARK: - Rate normalisation

@Suite("Rate normalisation")
struct RateNormalisationTests {
    @Test func hourlyRateUnchanged() {
        #expect(RateType.hourly.normalizedHourlyRate(from: 100) == 100)
    }

    @Test func dailyRateDividedByEight() {
        #expect(RateType.daily.normalizedHourlyRate(from: 800) == 100)
    }
}

// MARK: - Cost calculation

@Suite("Meeting cost calculation")
struct MeetingCostTests {
    @Test @MainActor func staticCostFromMeetingLength() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let p1 = MeetingParticipant(firstName: "A", lastName: "B", hourlyRate: 100)
        let p2 = MeetingParticipant(firstName: "C", lastName: "D", hourlyRate: 50)
        context.insert(p1)
        context.insert(p2)

        let meeting = MeetingModel(meetingName: "Test")
        meeting.participants = [p1, p2]
        meeting.meetingLength = 3600
        context.insert(meeting)

        let cost = meeting.meetingLength * meeting.participants.reduce(0) { $0 + $1.hourlyRate } / 3600
        #expect(cost == 150.0)
    }

    @Test @MainActor func endMeetingMaterialisesCost() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let p = MeetingParticipant(firstName: "A", lastName: "B", hourlyRate: 100)
        context.insert(p)

        let meeting = MeetingModel(meetingName: "Test",
                                   meetingStart: Date.now.addingTimeInterval(-60))
        meeting.participants = [p]
        meeting.isRunning = true
        context.insert(meeting)

        meeting.endMeeting()

        #expect(meeting.isRunning == false)
        #expect(meeting.meetingCost > 0)
        #expect(meeting.meetingLength > 0)
    }
}

// MARK: - Timer / pause

@Suite("Timer and pause")
struct TimerTests {
    @Test @MainActor func liveElapsedReturnsMeetingLengthWhenStopped() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let meeting = MeetingModel(meetingName: "Test")
        meeting.meetingLength = 120
        meeting.isRunning = false
        context.insert(meeting)

        #expect(meeting.liveElapsed == 120)
    }

    @Test @MainActor func liveElapsedAdvancesWhenRunning() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let meeting = MeetingModel(meetingName: "Test",
                                   meetingStart: Date.now.addingTimeInterval(-10))
        meeting.isRunning = true
        context.insert(meeting)

        #expect(meeting.liveElapsed >= 10)
    }
}

// MARK: - Resource validation

@Suite("Resource validation")
struct ResourceValidationTests {
    @Test @MainActor func humanAlwaysAllowed() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let human = MeetingParticipant(firstName: "A", lastName: "B",
                                       hourlyRate: 0,
                                       participantType: ParticipantType.human)
        context.insert(human)

        let meeting1 = MeetingModel(meetingName: "M1")
        meeting1.isRunning = true
        meeting1.participants = [human]
        context.insert(meeting1)

        let meeting2 = MeetingModel(meetingName: "M2")
        meeting2.isRunning = true
        context.insert(meeting2)
        try context.save()

        let allowed = try meeting2.canAdd(human)
        #expect(allowed == true)
    }

    @Test @MainActor func resourceBlockedInSecondRunningMeeting() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let resource = MeetingParticipant(firstName: "Room", lastName: "A",
                                          hourlyRate: 0,
                                          participantType: ParticipantType.resource)
        context.insert(resource)

        let meeting1 = MeetingModel(meetingName: "M1")
        meeting1.isRunning = true
        meeting1.participants = [resource]
        context.insert(meeting1)

        let meeting2 = MeetingModel(meetingName: "M2")
        meeting2.isRunning = true
        context.insert(meeting2)
        try context.save()

        let allowed = try meeting2.canAdd(resource)
        #expect(allowed == false)
    }
}
