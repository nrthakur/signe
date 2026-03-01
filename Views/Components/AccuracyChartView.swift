import SwiftUI
import Charts

struct AccuracyChartView: View {
    let data: [DailyAccuracy]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Accuracy Over Time", systemImage: "chart.xyaxis.line")
                .font(.system(.headline, design: .rounded))

            if data.isEmpty {
                emptyState
            } else {
                chartView
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var chartView: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Accuracy", point.accuracy)
            )
            .foregroundStyle(.indigo.gradient)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Accuracy", point.accuracy)
            )
            .foregroundStyle(.indigo.opacity(0.08))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Accuracy", point.accuracy)
            )
            .foregroundStyle(.indigo)
            .symbolSize(24)
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v * 100))%")
                            .font(.system(.caption2, design: .rounded))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 180)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title)
                .foregroundStyle(.tertiary)
            Text("Complete practice sessions to see your progress chart")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}
