//
//  MeetingParticipantTypes.swift
//  MeetClock02
//
//  Created by Arthur Nsereko Kahwa on 2026-04-05.
//

import Foundation

enum RateType: String, Codable, CaseIterable {
    case hourly
    case daily

    nonisolated func normalizedHourlyRate(from rate: Double) -> Double {
        switch self {
        case .hourly: return rate
        case .daily:  return rate / 8
        }
    }
}

enum ParticipantType: String, Codable, CaseIterable {
    case human
    case resource
}
