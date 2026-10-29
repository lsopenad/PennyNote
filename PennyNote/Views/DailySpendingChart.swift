import SwiftUI
import Charts

// Gasto por día de un mes o una semana con la media diaria. Al tocar una barra se muestra su importe.
struct DailySpendingChart: View {
    @Environment(\.currency) private var currency

    // Primer instante de cada día y su gasto, en el mismo orden.
    let days: [Date]
    let dailyTotals: [Decimal]
    // Días ya empezados: la media se calcula sobre ellos, no sobre el periodo entero.
    let elapsedDays: Int

    // Posición del día seleccionado (1 = el primero).
    @State private var selectedDay: Int?

    private var items: [(day: Int, date: Date, amount: Double)] {
        zip(days, dailyTotals).enumerated().map { index, item in
            (day: index + 1, date: item.0, amount: item.1.doubleValue)
        }
    }

    private var average: Double? {
        guard elapsedDays > 0 else { return nil }
        return dailyTotals.prefix(elapsedDays).sum(of: { $0 }).doubleValue / Double(elapsedDays)
    }

    // Una semana cabe con el nombre de cada día; un mes, con el número cada 7 días.
    private var isWeek: Bool {
        days.count <= 7
    }

    var body: some View {
        let items = self.items
        Chart {
            ForEach(items, id: \.day) { item in
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

            if let selectedDay, let item = items.first(where: { $0.day == selectedDay }) {
                RuleMark(x: .value("Día", item.date, unit: .day))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        selectionLabel(date: item.date, amount: item.amount)
                    }
            }
        }
        .chartXAxis {
            if isWeek {
                AxisMarks(values: days) {
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                }
            } else {
                AxisMarks(values: .stride(by: .day, count: 7)) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day())
                }
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
        let tappedDay = Calendar.current.startOfDay(for: date)
        guard let index = days.firstIndex(of: tappedDay) else { return }
        let day = index + 1
        selectedDay = selectedDay == day ? nil : day
    }
}
