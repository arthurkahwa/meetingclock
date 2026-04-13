//
//  MeetingParticipant.swift
//  MeetClock02
//
//  Created by Arthur Nsereko Kahwa on 2026-03-05.
//

import Foundation
import SwiftData

@Model
final class MeetingParticipant {
    var firstName: String = ""
    var lastName: String = ""
    var hourlyRate: Double = 0.0
    var rateType: RateType = RateType.hourly
    var participantType: ParticipantType = ParticipantType.human
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
    var meetings: [MeetingModel] = []

    init(firstName: String,
         lastName: String,
         hourlyRate: Double,
         rateType: RateType = RateType.hourly,
         participantType: ParticipantType = ParticipantType.human,
         currencyCode: String = Locale.current.currency?.identifier ?? "USD",
         meetings: [MeetingModel] = []) {
        self.firstName = firstName
        self.lastName = lastName
        self.hourlyRate = rateType.normalizedHourlyRate(from: hourlyRate)
        self.rateType = rateType
        self.participantType = participantType
        self.currencyCode = currencyCode
        self.meetings = meetings
    }
}
