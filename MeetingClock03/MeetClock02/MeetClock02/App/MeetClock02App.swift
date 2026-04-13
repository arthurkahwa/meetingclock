// MeetClock02/App/MeetClock02App.swift

import SwiftUI
import SwiftData

@main
struct MeetClock02App: App {
    @State private var exchangeRateService = ExchangeRateService()

    let modelContainer: ModelContainer = {
        let schema = Schema([MeetingModel.self, MeetingParticipant.self])
        let isUITesting = CommandLine.arguments.contains("--uitesting")
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
                .environment(exchangeRateService)
                .task { await exchangeRateService.fetchRates() }
        }
    }
}
