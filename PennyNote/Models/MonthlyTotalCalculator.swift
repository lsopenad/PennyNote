import Foundation
import SwiftData

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

        let expenses = (try? context.fetch(descriptor)) ?? []
        return expenses.reduce(Decimal.zero) { $0 + $1.amount }
    }
}
