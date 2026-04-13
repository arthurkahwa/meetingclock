// MeetClock02/Views/StatisticsView.swift

import SwiftUI
import SwiftData
import Charts

enum ChartKind: String, CaseIterable, Identifiable {
    case costPerMeeting         = "Cost per Meeting"
    case participantsPerMeeting = "Participants per Meeting"
    case horizontalCostBar      = "Cost Comparison"
    case durationPerMeeting     = "Duration per Meeting"
    case costOverTime           = "Cost Over Time"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .costPerMeeting:         "dollarsign.circle"
        case .participantsPerMeeting: "person.2"
        case .horizontalCostBar:      "chart.bar.horizontal"
        case .durationPerMeeting:     "clock"
        case .costOverTime:           "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - AXChartDescriptorRepresentable conformances

private struct CostChartDescriptor: AXChartDescriptorRepresentable {
    let meetings: [MeetingModel]

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Meeting",
            categoryOrder: meetings.map { $0.meetingName.isEmpty ? "Untitled" : $0.meetingName }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Cost",
            range: 0...max(1, meetings.map(\.meetingCost).max() ?? 1),
            gridlinePositions: []
        ) { value in "\(value.formatted(.number.precision(.fractionLength(2))))" }

        let series = AXDataSeriesDescriptor(
            name: "Cost per meeting",
            isContinuous: false,
            dataPoints: meetings.map { meeting in
                AXDataPoint(
                    x: meeting.meetingName.isEmpty ? "Untitled" : meeting.meetingName,
                    y: meeting.meetingCost,
                    additionalValues: [],
                    label: meeting.meetingCost.formatted(.currency(code: meeting.meetingCurrencyCode))
                )
            }
        )
        return AXChartDescriptor(
            title: "Cost per Meeting",
            summary: "Bar chart showing total cost for each completed meeting",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

private struct ParticipantsChartDescriptor: AXChartDescriptorRepresentable {
    let meetings: [MeetingModel]

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Meeting",
            categoryOrder: meetings.map { $0.meetingName.isEmpty ? "Untitled" : $0.meetingName }
        )
        let maxParticipants = meetings.map { Double($0.participants.count) }.max() ?? 1
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Participants",
            range: 0...max(1, maxParticipants),
            gridlinePositions: []
        ) { value in "\(Int(value))" }

        let series = AXDataSeriesDescriptor(
            name: "Participants per meeting",
            isContinuous: false,
            dataPoints: meetings.map { meeting in
                AXDataPoint(
                    x: meeting.meetingName.isEmpty ? "Untitled" : meeting.meetingName,
                    y: Double(meeting.participants.count),
                    additionalValues: [],
                    label: "\(meeting.participants.count) participant\(meeting.participants.count == 1 ? "" : "s")"
                )
            }
        )
        return AXChartDescriptor(
            title: "Participants per Meeting",
            summary: "Bar chart showing number of participants for each completed meeting",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

// Horizontal cost bar: data table uses meeting name as categorical x, cost as numeric y
// (mirrors the visual chart's data regardless of visual axis orientation)
private struct HorizontalCostChartDescriptor: AXChartDescriptorRepresentable {
    let meetings: [MeetingModel]

    func makeChartDescriptor() -> AXChartDescriptor {
        let sorted = meetings.sorted { $0.meetingCost > $1.meetingCost }
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Meeting (ranked by cost)",
            categoryOrder: sorted.map { $0.meetingName.isEmpty ? "Untitled" : $0.meetingName }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Cost",
            range: 0...max(1, sorted.map(\.meetingCost).max() ?? 1),
            gridlinePositions: []
        ) { value in "\(value.formatted(.number.precision(.fractionLength(2))))" }

        let series = AXDataSeriesDescriptor(
            name: "Cost comparison",
            isContinuous: false,
            dataPoints: sorted.map { meeting in
                AXDataPoint(
                    x: meeting.meetingName.isEmpty ? "Untitled" : meeting.meetingName,
                    y: meeting.meetingCost,
                    additionalValues: [],
                    label: meeting.meetingCost.formatted(.currency(code: meeting.meetingCurrencyCode))
                )
            }
        )
        return AXChartDescriptor(
            title: "Cost Comparison",
            summary: "Meetings ranked by total cost, highest first",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

private struct DurationChartDescriptor: AXChartDescriptorRepresentable {
    let meetings: [MeetingModel]

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Meeting",
            categoryOrder: meetings.map { $0.meetingName.isEmpty ? "Untitled" : $0.meetingName }
        )
        let maxMinutes = meetings.map { $0.meetingLength / 60 }.max() ?? 1
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Duration (minutes)",
            range: 0...max(1, maxMinutes),
            gridlinePositions: []
        ) { value in "\(Int(value)) min" }

        let series = AXDataSeriesDescriptor(
            name: "Duration per meeting",
            isContinuous: false,
            dataPoints: meetings.map { meeting in
                let minutes = meeting.meetingLength / 60
                return AXDataPoint(
                    x: meeting.meetingName.isEmpty ? "Untitled" : meeting.meetingName,
                    y: minutes,
                    additionalValues: [],
                    label: "\(Int(minutes)) minute\(Int(minutes) == 1 ? "" : "s")"
                )
            }
        )
        return AXChartDescriptor(
            title: "Duration per Meeting",
            summary: "Bar chart showing duration in minutes for each completed meeting",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

private struct CostOverTimeChartDescriptor: AXChartDescriptorRepresentable {
    let meetings: [MeetingModel]

    func makeChartDescriptor() -> AXChartDescriptor {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short

        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Date",
            categoryOrder: meetings.map { dateFormatter.string(from: $0.meetingStart) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Cost",
            range: 0...max(1, meetings.map(\.meetingCost).max() ?? 1),
            gridlinePositions: []
        ) { value in "\(value.formatted(.number.precision(.fractionLength(2))))" }

        let series = AXDataSeriesDescriptor(
            name: "Cost over time",
            isContinuous: true,
            dataPoints: meetings.map { meeting in
                AXDataPoint(
                    x: dateFormatter.string(from: meeting.meetingStart),
                    y: meeting.meetingCost,
                    additionalValues: [],
                    label: meeting.meetingCost.formatted(.currency(code: meeting.meetingCurrencyCode))
                )
            }
        )
        return AXChartDescriptor(
            title: "Cost Over Time",
            summary: "Line chart showing meeting cost over time, ordered by meeting start date",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

// MARK: - StatisticsView

struct StatisticsView: View {
    @Query(sort: \MeetingModel.meetingStart) private var meetings: [MeetingModel]
    @State private var visible: Set<ChartKind> = Set(ChartKind.allCases)

    private var completed: [MeetingModel] {
        meetings.filter { !$0.isRunning && $0.meetingLength > 0 }
    }

    var body: some View {
        ScrollView {
            if completed.count < 2 {
                ContentUnavailableView(
                    "Not Enough Data",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Complete at least 2 meetings to see statistics.")
                )
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 20, pinnedViews: []) {
                    summaryCards

                    if Set(completed.map(\.meetingCurrencyCode)).count > 1 {
                        Label("Mixed currencies — costs shown in each meeting's own currency", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .accessibilityLabel("Warning: meetings use different currencies. Costs are shown in each meeting's own currency and are not directly comparable.")
                    }

                    chartSection(.costPerMeeting) {
                        Chart(completed) { meeting in
                            BarMark(
                                x: .value("Meeting", meeting.meetingName.isEmpty ? "Untitled" : meeting.meetingName),
                                y: .value("Cost", meeting.meetingCost)
                            )
                            .foregroundStyle(Color.accentColor)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic) { _ in
                                AxisValueLabel(orientation: .verticalReversed)
                            }
                        }
                        .frame(height: 200)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Cost per Meeting chart")
                        .accessibilityChartDescriptor(CostChartDescriptor(meetings: completed))
                    }

                    chartSection(.participantsPerMeeting) {
                        Chart(completed) { meeting in
                            BarMark(
                                x: .value("Meeting", meeting.meetingName.isEmpty ? "Untitled" : meeting.meetingName),
                                y: .value("Participants", meeting.participants.count)
                            )
                            .foregroundStyle(Color.indigo)
                        }
                        .chartYAxis {
                            AxisMarks(values: .stride(by: 1))
                        }
                        .frame(height: 200)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Participants per Meeting chart")
                        .accessibilityChartDescriptor(ParticipantsChartDescriptor(meetings: completed))
                    }

                    chartSection(.horizontalCostBar) {
                        Chart(completed.sorted { $0.meetingCost > $1.meetingCost }) { meeting in
                            BarMark(
                                x: .value("Cost", meeting.meetingCost),
                                y: .value("Meeting", meeting.meetingName.isEmpty ? "Untitled" : meeting.meetingName)
                            )
                            .foregroundStyle(Color.accentColor.gradient)
                            .annotation(position: .trailing) {
                                Text(meeting.meetingCost, format: .currency(code: meeting.meetingCurrencyCode))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: max(120, CGFloat(completed.count) * 44))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Cost Comparison chart")
                        .accessibilityChartDescriptor(HorizontalCostChartDescriptor(meetings: completed))
                    }

                    chartSection(.durationPerMeeting) {
                        Chart(completed) { meeting in
                            BarMark(
                                x: .value("Meeting", meeting.meetingName.isEmpty ? "Untitled" : meeting.meetingName),
                                y: .value("Minutes", meeting.meetingLength / 60)
                            )
                            .foregroundStyle(Color.teal)
                        }
                        .chartYAxisLabel("minutes")
                        .frame(height: 200)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Duration per Meeting chart")
                        .accessibilityChartDescriptor(DurationChartDescriptor(meetings: completed))
                    }

                    chartSection(.costOverTime) {
                        Chart(completed) { meeting in
                            LineMark(
                                x: .value("Date", meeting.meetingStart),
                                y: .value("Cost", meeting.meetingCost)
                            )
                            .foregroundStyle(Color.accentColor)
                            PointMark(
                                x: .value("Date", meeting.meetingStart),
                                y: .value("Cost", meeting.meetingCost)
                            )
                            .foregroundStyle(Color.accentColor)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month().day())
                            }
                        }
                        .frame(height: 200)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Cost Over Time chart")
                        .accessibilityChartDescriptor(CostOverTimeChartDescriptor(meetings: completed))
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Statistics")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu("Charts", systemImage: "checklist") {
                    ForEach(ChartKind.allCases) { kind in
                        Toggle(kind.rawValue, isOn: Binding(
                            get: { visible.contains(kind) },
                            set: { isOn in
                                if isOn { visible.insert(kind) } else { visible.remove(kind) }
                            }
                        ))
                        .accessibilityHint("Shows or hides the \(kind.rawValue) chart")
                    }
                }
                .accessibilityLabel("Show or hide charts")
                .accessibilityHint("Toggle individual chart visibility")
            }
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                summaryCard(title: "Meetings", systemImage: "calendar.badge.checkmark") {
                    Text("\(completed.count)")
                        .font(.title2.bold())
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Total meetings: \(completed.count)")

                summaryCard(title: "Total Cost", systemImage: "dollarsign.circle") {
                    let currencies = Set(completed.map(\.meetingCurrencyCode))
                    if currencies.count == 1, let code = currencies.first {
                        Text(completed.reduce(0) { $0 + $1.meetingCost }, format: .currency(code: code))
                            .font(.title2.bold())
                    } else {
                        Text("Mixed")
                            .font(.title2.bold())
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel({
                    let currencies = Set(completed.map(\.meetingCurrencyCode))
                    if currencies.count == 1, let code = currencies.first {
                        let total = completed.reduce(0) { $0 + $1.meetingCost }
                        return "Total cost: \(total.formatted(.currency(code: code)))"
                    } else {
                        return "Total cost: Mixed currencies"
                    }
                }())

                summaryCard(title: "Avg Duration", systemImage: "clock") {
                    let avg = completed.reduce(0) { $0 + $1.meetingLength } / Double(completed.count)
                    Text(formattedDuration(avg))
                        .font(.title2.bold())
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel({
                    let avg = completed.reduce(0) { $0 + $1.meetingLength } / Double(completed.count)
                    return "Average duration: \(formattedDuration(avg))"
                }())

                if let priciest = completed.max(by: { $0.meetingCost < $1.meetingCost }) {
                    summaryCard(title: "Most Expensive", systemImage: "trophy") {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(priciest.meetingName.isEmpty ? "Untitled" : priciest.meetingName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(priciest.meetingCost, format: .currency(code: priciest.meetingCurrencyCode))
                                .font(.title2.bold())
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Most expensive meeting: \(priciest.meetingName.isEmpty ? "Untitled" : priciest.meetingName), \(priciest.meetingCost.formatted(.currency(code: priciest.meetingCurrencyCode)))")
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func summaryCard(title: String, systemImage: String, @ViewBuilder value: () -> some View) -> some View {
        GroupBox(label: Label(title, systemImage: systemImage)) {
            value()
                .padding(.top, 4)
        }
        .frame(minWidth: 120)
    }

    // MARK: - Chart Section Helper

    @ViewBuilder
    private func chartSection(_ kind: ChartKind, @ViewBuilder content: () -> some View) -> some View {
        if visible.contains(kind) {
            GroupBox(label: Label(kind.rawValue, systemImage: kind.symbol)) {
                content()
                    .padding(.top, 8)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
