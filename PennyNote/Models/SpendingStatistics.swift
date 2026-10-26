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

    static func monthStart(of date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    // Días del mes que ya han empezado: hasta hoy en el mes en curso, el mes entero en los pasados
    // y ninguno en los futuros.
    static func elapsedDays(inMonthOf date: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
        let month = monthStart(of: date, calendar: calendar)
        let currentMonth = monthStart(of: now, calendar: calendar)
        if month == currentMonth { return calendar.component(.day, from: now) }
        if month > currentMonth { return 0 }
        return calendar.range(of: .day, in: .month, for: month)?.count ?? 0
    }

    static func expenses(_ expenses: [Expense], inMonthOf date: Date, calendar: Calendar = .current) -> [Expense] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        return expenses.filter { !$0.isSoftDeleted && $0.date >= interval.start && $0.date < interval.end }
    }

    static func monthSpending(_ expenses: [Expense], monthOf date: Date, calendar: Calendar = .current) -> MonthSpending {
        let empty = MonthSpending.empty(monthStart: monthStart(of: date, calendar: calendar), calendar: calendar)
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
            .map { items in CategoryTotal(category: items[0].category, total: items.reduce(.zero) { $0 + $1.amount }) }
            .sorted(by: isLarger)
    }

    // De mayor a menor gasto; solo aparecen los métodos con gasto.
    static func paymentMethodTotals(_ expenses: [Expense]) -> [PaymentMethodTotal] {
        let grouped = Dictionary(grouping: expenses.filter { !$0.isSoftDeleted }, by: \.paymentMethod)
        return grouped
            .map { method, items in PaymentMethodTotal(paymentMethod: method, total: items.reduce(.zero) { $0 + $1.amount }) }
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.paymentMethod.rawValue < $1.paymentMethod.rawValue }
    }

    // `count` meses consecutivos que acaban en el mes de `date`, del más antiguo al más reciente.
    // Los meses sin gasto aparecen con total cero.
    static func monthlyTotals(_ expenses: [Expense], endingInMonthOf date: Date, count: Int, calendar: Calendar = .current) -> [MonthTotal] {
        let lastMonth = monthStart(of: date, calendar: calendar)
        let months = (0..<count).reversed().compactMap { calendar.date(byAdding: .month, value: -$0, to: lastMonth) }
        var totals = Dictionary(uniqueKeysWithValues: months.map { ($0, Decimal.zero) })
        for expense in expenses where !expense.isSoftDeleted {
            let month = monthStart(of: expense.date, calendar: calendar)
            if totals[month] != nil {
                totals[month]! += expense.amount
            }
        }
        return months.map { MonthTotal(monthStart: $0, total: totals[$0] ?? .zero) }
    }

    // A igualdad de gasto se ordena por nombre para que el orden no baile entre recálculos.
    private static func isLarger(_ lhs: CategoryTotal, _ rhs: CategoryTotal) -> Bool {
        if lhs.total != rhs.total { return lhs.total > rhs.total }
        let lhsName = lhs.category?.name ?? ExpenseCategory.uncategorizedLabel
        let rhsName = rhs.category?.name ?? ExpenseCategory.uncategorizedLabel
        return lhsName.localizedStandardCompare(rhsName) == .orderedAscending
    }
}
