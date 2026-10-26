import Foundation
import SwiftData

enum MonthlyTotalCalculator {
    // Recalcula el gasto del mes en curso y del anterior y lo publica en el App Group para los widgets.
    static func refreshWidgetSnapshot(in context: ModelContext) {
        let now = Date.now
        let calendar = Calendar.current
        let currentMonthStart = SpendingStatistics.monthStart(of: now, calendar: calendar)
        guard
            let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart),
            let end = calendar.dateInterval(of: .month, for: now)?.end
        else { return }

        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { expense in
                expense.isSoftDeleted == false && expense.date >= previousMonthStart && expense.date < end
            }
        )
        let expenses = context.fetchOrEmpty(descriptor, failureMessage: "Fallo al leer los gastos para el widget")
        let currentExpenses = SpendingStatistics.expenses(expenses, inMonthOf: now, calendar: calendar)

        let topCategories = SpendingStatistics.categoryTotals(currentExpenses)
            .prefix(widgetTopCategoryCount)
            .map { item in
                WidgetSnapshot.CategoryTotal(
                    name: item.category?.name ?? ExpenseCategory.uncategorizedLabel,
                    symbolName: item.category?.symbolName ?? ExpenseCategory.uncategorizedSymbolName,
                    colorName: item.category?.color?.rawValue,
                    total: item.total
                )
            }

        WidgetSnapshotStore.write(WidgetSnapshot(
            current: SpendingStatistics.monthSpending(currentExpenses, monthOf: now, calendar: calendar),
            previous: SpendingStatistics.monthSpending(expenses, monthOf: previousMonthStart, calendar: calendar),
            topCategories: Array(topCategories)
        ))
    }

    // Las que caben en el widget mediano.
    private static let widgetTopCategoryCount = 3
}
