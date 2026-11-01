import Foundation
import SwiftData
import Testing
@testable import PennyNote

@MainActor
struct ExpenseListPagingTests {
    private let context: ModelContext

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, RecurringExpense.self, configurations: configuration)
        context = ModelContext(container)
    }

    @Test func shortListsAreShownWhole() throws {
        let expenses = [Expense(amount: 1, date: try date(2026, 3, 2)), Expense(amount: 2, date: try date(2026, 3, 1))]

        #expect(ExpenseDayList.visibleExpenses(expenses, limit: 2).count == 2)
        #expect(ExpenseDayList.visibleExpenses(expenses, limit: 5).count == 2)
    }

    @Test func pageEndsAtTheEndOfItsLastDay() throws {
        // Del más reciente al más antiguo: el límite cae en medio del día 2.
        let expenses = [
            Expense(amount: 1, date: try date(2026, 3, 3, hour: 9)),
            Expense(amount: 2, date: try date(2026, 3, 2, hour: 20)),
            Expense(amount: 3, date: try date(2026, 3, 2, hour: 10)),
            Expense(amount: 4, date: try date(2026, 3, 2, hour: 8)),
            Expense(amount: 5, date: try date(2026, 3, 1, hour: 12)),
        ]

        let visible = ExpenseDayList.visibleExpenses(expenses, limit: 2)

        #expect(visible.map(\.amount) == [1, 2, 3, 4])
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) throws -> Date {
        try #require(DateComponents(calendar: .current, year: year, month: month, day: day, hour: hour).date)
    }
}
