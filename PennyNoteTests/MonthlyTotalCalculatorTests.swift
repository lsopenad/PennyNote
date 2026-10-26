import Foundation
import SwiftData
import Testing
@testable import PennyNote

@MainActor
struct MonthlyTotalCalculatorTests {
    private let context: ModelContext

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, configurations: configuration)
        context = ModelContext(container)
    }

    @Test func sumsOnlyNonDeletedExpensesOfTheReferenceMonth() throws {
        let deleted = Expense(amount: 100, date: try date(2026, 3, 10))
        deleted.isDeleted = true

        let expenses = [
            Expense(amount: Decimal(string: "10.50")!, date: try date(2026, 3, 1)),
            Expense(amount: Decimal(string: "4.25")!, date: try date(2026, 3, 31, hour: 23, minute: 59)),
            Expense(amount: 7, date: try date(2026, 2, 28, hour: 23, minute: 59)),
            Expense(amount: 9, date: try date(2026, 4, 1)),
            deleted,
        ]
        expenses.forEach(context.insert)

        let total = MonthlyTotalCalculator.total(for: try date(2026, 3, 15), in: context)
        #expect(total == Decimal(string: "14.75"))
    }

    @Test func returnsZeroWithoutExpenses() throws {
        #expect(MonthlyTotalCalculator.total(for: try date(2026, 3, 15), in: context) == .zero)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) throws -> Date {
        try #require(DateComponents(calendar: .current, year: year, month: month, day: day, hour: hour, minute: minute).date)
    }
}
