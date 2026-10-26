import SwiftUI

struct MonthHeaderView: View {
    let current: MonthSpending
    let previous: MonthSpending
    // Día de hoy dentro del mes en curso.
    let today: Int

    private var comparisonText: String? {
        SpendingComparison.change(current: current, previous: previous, throughDay: today)
            .map { DisplayFormat.comparison($0, previousMonth: previous.monthStart) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DisplayFormat.monthName(current.monthStart))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(DisplayFormat.currency(current.total))
                .font(.system(size: 40, weight: .bold, design: .rounded))
            if let comparisonText {
                Text(comparisonText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            DailySpendingBars(dailyTotals: current.dailyTotals, elapsedDays: today, highlightedDay: today)
                .frame(height: 36)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .contentShape(Rectangle())
    }
}

#Preview {
    MonthHeaderView(
        current: MonthSpending(monthStart: .now, dailyTotals: [12, 0, 30, 4, 0, 0, 55, 8, 20, 0] + Array(repeating: 0, count: 21)),
        previous: MonthSpending(monthStart: .now, dailyTotals: Array(repeating: 10, count: 30)),
        today: 10
    )
}
