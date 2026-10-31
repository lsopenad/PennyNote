import SwiftUI
import WidgetKit

struct HomeScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MonthlyTotalEntry

    private var display: WidgetDisplay { entry.display }

    var body: some View {
        content
            // Los widgets de inicio abren Estadísticas. Añadir un gasto queda para el de la pantalla
            // de bloqueo y el control del Centro de control.
            .widgetURL(DeepLinkURL.statistics)
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 16) {
                summary
                topCategories
            }
        default:
            summary
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.monthLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(DisplayFormat.currency(entry.total, in: entry.currency))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let previous = display.previous, let change = display.comparison {
                Text(DisplayFormat.comparison(change, previousMonth: previous.monthStart, short: true))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 6)
            DailySpendingBars(
                dailyTotals: display.current.dailyTotals,
                elapsedDays: display.day,
                highlightedDay: display.day
            )
            .frame(height: 28)
            .widgetAccentable()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var topCategories: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Más gasto")
                .font(.caption)
                .foregroundStyle(.secondary)

            if display.topCategories.isEmpty {
                Spacer()
                Text("Sin gastos este mes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                // Por posición: dos categorías pueden llamarse igual.
                ForEach(Array(display.topCategories.enumerated()), id: \.offset) { _, category in
                    categoryRow(category)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func categoryRow(_ category: WidgetSnapshot.CategoryTotal) -> some View {
        let color = CategoryColor.color(named: category.colorName)
        return HStack(spacing: 6) {
            Image(systemName: category.symbolName)
                .font(.caption2)
                .foregroundStyle(color)
                .frame(width: 20, height: 20)
                .background(color.opacity(0.15), in: Circle())
            Text(category.name)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(DisplayFormat.currency(category.total, in: entry.currency, showsCents: false))
                .font(.caption.monospacedDigit())
                .lineLimit(1)
        }
    }
}
