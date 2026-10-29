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

    struct PeriodTotal: Identifiable {
        let period: StatisticsPeriod
        let total: Decimal

        var id: StatisticsPeriod { period }
    }

    // Días del periodo que ya han empezado: hasta hoy en el periodo en curso, todos en los pasados y
    // ninguno en los futuros.
    static func elapsedDays(in period: StatisticsPeriod, now: Date = .now, calendar: Calendar = .current) -> Int {
        period.days(calendar: calendar).filter { $0 <= now }.count
    }

    static func expenses(_ expenses: [Expense], in period: StatisticsPeriod, calendar: Calendar = .current) -> [Expense] {
        let interval = period.interval(calendar: calendar)
        return expenses.filter { !$0.isSoftDeleted && $0.date >= interval.start && $0.date < interval.end }
    }

    // Gasto de cada día del periodo, en el orden de StatisticsPeriod.days.
    static func dailyTotals(_ expenses: [Expense], in period: StatisticsPeriod, calendar: Calendar = .current) -> [Decimal] {
        let days = period.days(calendar: calendar)
        var totals = Dictionary(uniqueKeysWithValues: days.map { ($0, Decimal.zero) })
        for expense in self.expenses(expenses, in: period, calendar: calendar) {
            totals[calendar.startOfDay(for: expense.date), default: .zero] += expense.amount
        }
        return days.map { totals[$0] ?? .zero }
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

    // `count` periodos consecutivos que acaban en `period`, del más antiguo al más reciente. Los que
    // no tienen gasto aparecen con total cero.
    static func periodTotals(_ expenses: [Expense], endingIn period: StatisticsPeriod, count: Int, calendar: Calendar = .current) -> [PeriodTotal] {
        let periods = (0..<count).reversed().map { period.moved(by: -$0, calendar: calendar) }
        var totals = Dictionary(uniqueKeysWithValues: periods.map { ($0, Decimal.zero) })
        for expense in expenses where !expense.isSoftDeleted {
            let containing = StatisticsPeriod(kind: period.kind, containing: expense.date, calendar: calendar)
            if totals[containing] != nil {
                totals[containing]! += expense.amount
            }
        }
        return periods.map { PeriodTotal(period: $0, total: totals[$0] ?? .zero) }
    }

    // Último periodo al que se puede llegar en Estadísticas: el actual o, si hay gastos con fecha
    // futura, el del más tardío.
    static func latestPeriod(_ kind: StatisticsPeriod.Kind, expenses: [Expense], now: Date = .now, calendar: Calendar = .current) -> StatisticsPeriod {
        let lastDate = expenses.lazy.filter { !$0.isSoftDeleted }.map(\.date).max() ?? now
        return StatisticsPeriod(kind: kind, containing: max(now, lastDate), calendar: calendar)
    }

    // A igualdad de gasto se ordena por nombre para que el orden no baile entre recálculos.
    private static func isLarger(_ lhs: CategoryTotal, _ rhs: CategoryTotal) -> Bool {
        if lhs.total != rhs.total { return lhs.total > rhs.total }
        return lhs.category.displayName.localizedStandardCompare(rhs.category.displayName) == .orderedAscending
    }
}
