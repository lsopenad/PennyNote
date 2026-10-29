import SwiftUI
import Charts

// Total de los últimos meses con el seleccionado resaltado. Tocar una barra selecciona ese mes.
struct MonthlyEvolutionChart: View {
    @Environment(\.currency) private var currency

    let totals: [SpendingStatistics.MonthTotal]
    @Binding var selectedMonth: Date

    private var average: Double? {
        guard !totals.isEmpty else { return nil }
        return totals.sum(of: \.total).doubleValue / Double(totals.count)
    }

    var body: some View {
        Chart {
            ForEach(totals) { item in
                BarMark(
                    x: .value("Mes", item.monthStart, unit: .month),
                    y: .value("Importe", item.total.doubleValue)
                )
                .foregroundStyle(Color.accentColor.opacity(item.monthStart == selectedMonth ? 1 : 0.35))
                .cornerRadius(3)
            }

            if let average {
                RuleMark(y: .value("Media", average))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) {
                AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
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
        .frame(height: 160)
        .padding(.vertical, 8)
        .accessibilityLabel("Evolución mensual del gasto")
    }

    private func select(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let x = location.x - geometry[plotFrame].origin.x
        guard let date: Date = proxy.value(atX: x) else { return }
        let month = Calendar.current.startOfMonth(for: date)
        guard totals.contains(where: { $0.monthStart == month }) else { return }
        withAnimation(.snappy) {
            selectedMonth = month
        }
    }
}
