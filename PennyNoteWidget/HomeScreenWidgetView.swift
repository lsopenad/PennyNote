import SwiftUI
import WidgetKit

struct HomeScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MonthlyTotalEntry

    private var display: WidgetDisplay { entry.display }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
    }

    // El pequeño solo admite un destino al tocarlo y abre "Añadir gasto", como antes de tener
    // gráfica. En el mediano la gráfica abre Estadísticas y el botón "+" añade un gasto.
    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 16) {
                summary
                topCategories
            }
            .widgetURL(DeepLinkURL.statistics)
        default:
            summary
                .widgetURL(DeepLinkURL.addExpense)
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
            HStack {
                Text("Más gasto")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Link(destination: DeepLinkURL.addExpense) {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.brand, in: Circle())
                }
                .accessibilityLabel("Añadir gasto")
            }

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
