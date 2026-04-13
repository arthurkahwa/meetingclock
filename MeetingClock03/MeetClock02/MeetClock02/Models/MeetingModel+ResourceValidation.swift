//
//  MeetingModel+ResourceValidation.swift
//  MeetClock02
//
//  Created by Arthur Nsereko Kahwa on 2026-04-05.
//

import Foundation
import SwiftData

extension MeetingModel {
    /// Returns `true` if `participant` can be added to this meeting.
    /// Human participants are always available.
    /// Resources may only attend one running meeting at a time.
    func canAdd(_ participant: MeetingParticipant) throws -> Bool {
        guard participant.participantType == .resource,
              let context = modelContext else { return true }

        let descriptor = FetchDescriptor<MeetingModel>(
            predicate: #Predicate<MeetingModel> { $0.isRunning }
        )
        let running = try context.fetch(descriptor)
        let pid = participant.persistentModelID

        return !running.contains { other in
            other.persistentModelID != persistentModelID &&
            other.participants.contains { $0.persistentModelID == pid }
        }
    }
}
