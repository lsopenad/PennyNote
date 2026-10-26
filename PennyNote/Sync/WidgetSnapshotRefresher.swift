import Foundation
import SwiftData

// Publica en el App Group lo que muestran los widgets, a partir de los gastos guardados.
enum WidgetSnapshotRefresher {
    // Recalcula el gasto del mes en curso y del anterior y lo publica para los widgets.
    static func refresh(in context: ModelContext) {
        let now = Date.now
        let calendar = Calendar.current
        guard
            let previousMonthStart = calendar.startOfPreviousMonth(for: now),
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
                    name: item.category.displayName,
                    symbolName: item.category.displaySymbolName,
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
