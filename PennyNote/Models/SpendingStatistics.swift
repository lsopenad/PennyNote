import Foundation

// Agregados de gasto para la cabecera, la pantalla de Estadísticas y el widget. Trabaja sobre
// gastos ya cargados (los de un @Query o un fetch) para no repetir consultas en cada cálculo.
enum SpendingStatistics {
    struct CategoryTotal: Identifiable {
        // nil agrupa los gastos sin categoría.
        let category: ExpenseCategory?
        let total: Decimal

        var id: String { category?.id.uuidString ?? "uncategorized" }
    }

    struct PaymentMethodTotal: Identifiable {
        let paymentMethod: PaymentMethod
        let total: Decimal

        var id: PaymentMethod { paymentMethod }
    }

    struct MonthTotal: Identifiable {
        let monthStart: Date
        let total: Decimal

        var id: Date { monthStart }
    }

    // Días del mes que ya han empezado: hasta hoy en el mes en curso, el mes entero en los pasados
    // y ninguno en los futuros.
    static func elapsedDays(inMonthOf date: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
        let month = calendar.startOfMonth(for: date)
        let currentMonth = calendar.startOfMonth(for: now)
        if month == currentMonth { return calendar.component(.day, from: now) }
        if month > currentMonth { return 0 }
        return calendar.numberOfDays(inMonthOf: month) ?? 0
    }

    static func expenses(_ expenses: [Expense], inMonthOf date: Date, calendar: Calendar = .current) -> [Expense] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        return expenses.filter { !$0.isSoftDeleted && $0.date >= interval.start && $0.date < interval.end }
    }

    static func monthSpending(_ expenses: [Expense], monthOf date: Date, calendar: Calendar = .current) -> MonthSpending {
        let empty = MonthSpending.empty(monthStart: calendar.startOfMonth(for: date), calendar: calendar)
        var dailyTotals = empty.dailyTotals
        for expense in self.expenses(expenses, inMonthOf: date, calendar: calendar) {
            let index = calendar.component(.day, from: expense.date) - 1
            if dailyTotals.indices.contains(index) {
                dailyTotals[index] += expense.amount
            }
        }
        return MonthSpending(monthStart: empty.monthStart, dailyTotals: dailyTotals)
    }

    // De mayor a menor gasto; solo aparecen las categorías con gasto.
    static func categoryTotals(_ expenses: [Expense]) -> [CategoryTotal] {
        let grouped = Dictionary(grouping: expenses.filter { !$0.isSoftDeleted }) { $0.category?.id }
        return grouped.values
            .map { items in CategoryTotal(category: items[0].category, total: items.sum(of: \.amount)) }
            .sorted(by: isLarger)
    }

    // De mayor a menor gasto; solo aparecen los métodos con gasto.
    static func paymentMethodTotals(_ expenses: [Expense]) -> [PaymentMethodTotal] {
        let grouped = Dictionary(grouping: expenses.filter { !$0.isSoftDeleted }, by: \.paymentMethod)
        return grouped
            .map { method, items in PaymentMethodTotal(paymentMethod: method, total: items.sum(of: \.amount)) }
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.paymentMethod.rawValue < $1.paymentMethod.rawValue }
    }

    // `count` meses consecutivos que acaban en el mes de `date`, del más antiguo al más reciente.
    // Los meses sin gasto aparecen con total cero.
    static func monthlyTotals(_ expenses: [Expense], endingInMonthOf date: Date, count: Int, calendar: Calendar = .current) -> [MonthTotal] {
        let lastMonth = calendar.startOfMonth(for: date)
        let months = (0..<count).reversed().compactMap { calendar.date(byAdding: .month, value: -$0, to: lastMonth) }
        var totals = Dictionary(uniqueKeysWithValues: months.map { ($0, Decimal.zero) })
        for expense in expenses where !expense.isSoftDeleted {
            let month = calendar.startOfMonth(for: expense.date)
            if totals[month] != nil {
                totals[month]! += expense.amount
            }
        }
        return months.map { MonthTotal(monthStart: $0, total: totals[$0] ?? .zero) }
    }

    // Último mes al que se puede llegar en Estadísticas: el actual o, si hay gastos con fecha futura,
    // el del más tardío.
    static func latestMonth(_ expenses: [Expense], now: Date = .now, calendar: Calendar = .current) -> Date {
        let currentMonth = calendar.startOfMonth(for: now)
        guard let lastDate = expenses.lazy.filter({ !$0.isSoftDeleted }).map(\.date).max() else { return currentMonth }
        return max(currentMonth, calendar.startOfMonth(for: lastDate))
    }

    // A igualdad de gasto se ordena por nombre para que el orden no baile entre recálculos.
    private static func isLarger(_ lhs: CategoryTotal, _ rhs: CategoryTotal) -> Bool {
        if lhs.total != rhs.total { return lhs.total > rhs.total }
        return lhs.category.displayName.localizedStandardCompare(rhs.category.displayName) == .orderedAscending
    }
}
