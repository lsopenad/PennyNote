import Foundation
import SwiftData

enum MonthlyTotalCalculator {
    static func total(for referenceDate: Date = .now, in context: ModelContext) -> Decimal {
        guard let interval = Calendar.current.dateInterval(of: .month, for: referenceDate) else {
            return .zero
        }
        let start = interval.start
        let end = interval.end

        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { expense in
                expense.isDeleted == false && expense.date >= start && expense.date < end
            }
        )
        let expenses = context.fetchOrEmpty(descriptor, failureMessage: "Fallo al calcular el total mensual")
        return expenses.reduce(Decimal.zero) { $0 + $1.amount }
    }

    // Recalcula el total del mes en curso y lo publica en el App Group para el widget.
    static func refreshSharedTotal(in context: ModelContext) {
        let now = Date.now
        let monthStart = Calendar.current.dateInterval(of: .month, for: now)?.start ?? now
        MonthlyTotalStore.write(total: total(for: now, in: context), monthStart: monthStart)
    }
}
