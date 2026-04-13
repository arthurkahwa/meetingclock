// MeetClock02/Services/ExchangeRateService.swift

import Foundation
import Observation

private struct ExchangeRateResponse: Decodable {
    let base_code: String
    let rates: [String: Double]
}

@MainActor
@Observable
final class ExchangeRateService {
    var rates: [String: Double] = [:]
    var isLoading = false

    func convert(_ amount: Double, from fromCode: String, to toCode: String) -> Double {
        guard fromCode != toCode else { return amount }
        guard let fromRate = rates[fromCode], fromRate > 0,
              let toRate = rates[toCode], toRate > 0 else { return amount }
        return amount * toRate / fromRate
    }

    func fetchRates() async {
        isLoading = true
        defer { isLoading = false }
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let decoded = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            guard decoded.base_code == "USD" else { return }
            var newRates = decoded.rates
            newRates["USD"] = 1.0
            rates = newRates
        } catch {
            // Keep existing rates on failure; silent degradation.
        }
    }
}
