import Foundation
import SwiftData
import os

enum MonthlyTotalCalculator {
    static func total(for referenceDate: Date = .now, in context: ModelContext) -> Decimal {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: referenceDate) else {
            return .zero
        }
        let start = interval.start
        let end = interval.end

        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { expense in
                expense.isDeleted == false && expense.date >= start && expense.date < end
            }
        )

        let expenses: [Expense]
        do {
            expenses = try context.fetch(descriptor)
        } catch {
            Log.data.error("Fallo al calcular el total mensual: \(error.localizedDescription)")
            expenses = []
        }
        return expenses.reduce(Decimal.zero) { $0 + $1.amount }
    }
}
