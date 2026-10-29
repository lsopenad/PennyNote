import SwiftUI
import Charts

// Gasto por día de un mes con la media diaria. Al tocar una barra se muestra su importe.
struct DailySpendingChart: View {
    @Environment(\.currency) private var currency

    let spending: MonthSpending
    // Días ya empezados del mes: la media se calcula sobre ellos, no sobre el mes entero.
    let elapsedDays: Int

    @State private var selectedDay: Int?

    private var days: [(day: Int, date: Date, amount: Double)] {
        let calendar = Calendar.current
        return spending.dailyTotals.enumerated().compactMap { index, amount in
            calendar.date(byAdding: .day, value: index, to: spending.monthStart)
                .map { (day: index + 1, date: $0, amount: amount.doubleValue) }
        }
    }

    private var average: Double? {
        guard elapsedDays > 0 else { return nil }
        return spending.total(throughDay: elapsedDays).doubleValue / Double(elapsedDays)
    }

    var body: some View {
        let days = self.days
        Chart {
            ForEach(days, id: \.day) { item in
                BarMark(
                    x: .value("Día", item.date, unit: .day),
                    y: .value("Importe", item.amount)
                )
                .foregroundStyle(Color.accentColor.opacity(selectedDay == nil || selectedDay == item.day ? 1 : 0.35))
                .cornerRadius(2)
            }

            if let average {
                RuleMark(y: .value("Media", average))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.secondary)
            }

            if let selectedDay, let item = days.first(where: { $0.day == selectedDay }) {
                RuleMark(x: .value("Día", item.date, unit: .day))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        selectionLabel(date: item.date, amount: item.amount)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(DisplayFormat.currency(Decimal(amount), in: currency, showsCents: false))
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        select(at: location, proxy: proxy, geometry: geometry)
                    }
            }
        }
        .frame(height: 180)
        .padding(.top, 24)
        .accessibilityLabel("Gasto diario")
    }

    private func selectionLabel(date: Date, amount: Double) -> some View {
        VStack(spacing: 0) {
            Text(date, format: .dateTime.day().month())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(DisplayFormat.currency(Decimal(amount), in: currency))
                .font(.caption.bold())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
    }

    // Tocar la barra seleccionada la deselecciona.
    private func select(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let x = location.x - geometry[plotFrame].origin.x
        guard let date: Date = proxy.value(atX: x) else { return }
        let calendar = Calendar.current
        guard calendar.isDate(date, equalTo: spending.monthStart, toGranularity: .month) else { return }
        let day = calendar.component(.day, from: date)
        selectedDay = selectedDay == day ? nil : day
    }
}
