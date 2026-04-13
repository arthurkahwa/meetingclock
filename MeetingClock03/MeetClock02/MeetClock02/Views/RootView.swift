//
//  RootView.swift
//  MeetClock02
//
//  Created by Arthur Nsereko Kahwa on 2026-04-05.
//

import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        TabView {
            Tab("Meetings", systemImage: "calendar") {
                if horizontalSizeClass == .regular {
                    SplitViewHost()
                } else {
                    StackViewHost()
                }
            }
            Tab("Participants", systemImage: "person.2") {
                ParticipantsTab()
            }
            Tab("Statistics", systemImage: "chart.bar.xaxis") {
                NavigationStack {
                    StatisticsView()
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

// MARK: - Participants Tab

private struct ParticipantsTab: View {
    @State private var path = [MeetingParticipant]()

    var body: some View {
        NavigationStack(path: $path) {
            AllParticipantsView(path: $path)
                .navigationDestination(for: MeetingParticipant.self) { participant in
                    EditMeetingParticipantView(participant: participant)
                }
        }
    }
}

// MARK: - iPad / macOS

private struct SplitViewHost: View {
    @State private var selectedMeeting: MeetingModel?

    var body: some View {
        NavigationSplitView {
            MeetingListView(selectedMeeting: $selectedMeeting)
        } detail: {
            NavigationStack {
                if let meeting = selectedMeeting {
                    MeetingView(meeting: meeting)
                } else {
                    ContentUnavailableView("Select a Meeting",
                                           systemImage: "clock.badge.questionmark",
                                           description: Text("Choose a meeting from the list or create one."))
                }
            }
        }
    }
}

// MARK: - iPhone

private struct StackViewHost: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            MeetingListView(path: $path)
                .navigationDestination(for: MeetingModel.self) { meeting in
                    MeetingView(meeting: meeting)
                }
        }
    }
}

#Preview {
    RootView()
}
