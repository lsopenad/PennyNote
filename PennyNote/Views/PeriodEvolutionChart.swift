import SwiftUI
import Charts

// Total de los últimos meses o semanas con el seleccionado resaltado. Tocar una barra selecciona
// ese periodo.
struct PeriodEvolutionChart: View {
    @Environment(\.currency) private var currency

    let totals: [SpendingStatistics.PeriodTotal]
    @Binding var selection: StatisticsPeriod

    // Las semanas se dibujan como categorías con su primer día ("26 oct"): Charts no sabe agrupar
    // por semanas que empiezan en lunes.
    private func label(for period: StatisticsPeriod) -> String {
        period.kind == .week ? DisplayFormat.shortDay(period.start) : DisplayFormat.shortMonth(period.start)
    }

    private var average: Double? {
        guard !totals.isEmpty else { return nil }
        return totals.sum(of: \.total).doubleValue / Double(totals.count)
    }

    var body: some View {
        Chart {
            ForEach(totals) { item in
                BarMark(
                    x: .value("Periodo", label(for: item.period)),
                    y: .value("Importe", item.total.doubleValue)
                )
                .foregroundStyle(Color.accentColor.opacity(item.period == selection ? 1 : 0.35))
                .cornerRadius(3)
            }

            if let average {
                RuleMark(y: .value("Media", average))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.secondary)
            }
        }
        // Solo la etiqueta: sin las líneas verticales que Charts pone por defecto a las categorías.
        .chartXAxis {
            AxisMarks {
                AxisValueLabel(centered: true)
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
        .accessibilityLabel(totals.first?.period.kind == .week ? "Evolución semanal del gasto" : "Evolución mensual del gasto")
    }

    private func select(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let x = location.x - geometry[plotFrame].origin.x
        guard
            let label: String = proxy.value(atX: x),
            let item = totals.first(where: { self.label(for: $0.period) == label })
        else { return }
        withAnimation(.snappy) {
            selection = item.period
        }
    }
}
