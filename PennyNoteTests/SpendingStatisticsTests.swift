import Foundation
import SwiftData
import Testing
@testable import PennyNote

@MainActor
struct SpendingStatisticsTests {
    private let context: ModelContext

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, configurations: configuration)
        context = ModelContext(container)
    }

    @Test func monthSpendingBucketsByDayAndIgnoresOtherMonthsAndDeleted() throws {
        let deleted = Expense(amount: 100, date: try date(2026, 3, 10))
        deleted.isDeleted = true
        let expenses = [
            Expense(amount: Decimal(string: "10.50")!, date: try date(2026, 3, 1)),
            Expense(amount: 2, date: try date(2026, 3, 1, hour: 20)),
            Expense(amount: Decimal(string: "4.25")!, date: try date(2026, 3, 31, hour: 23, minute: 59)),
            Expense(amount: 7, date: try date(2026, 2, 28, hour: 23, minute: 59)),
            Expense(amount: 9, date: try date(2026, 4, 1)),
            deleted,
        ]

        let spending = SpendingStatistics.monthSpending(expenses, monthOf: try date(2026, 3, 15))

        #expect(spending.monthStart == (try date(2026, 3, 1)))
        #expect(spending.dailyTotals.count == 31)
        #expect(spending.dailyTotals[0] == Decimal(string: "12.50"))
        #expect(spending.dailyTotals[9] == .zero)
        #expect(spending.dailyTotals[30] == Decimal(string: "4.25"))
        #expect(spending.total == Decimal(string: "16.75"))
    }

    @Test func categoryTotalsAreSortedAndGroupUncategorized() {
        let food = ExpenseCategory(name: "Comida", symbolName: "fork.knife", sortOrder: 0)
        let transport = ExpenseCategory(name: "Transporte", symbolName: "car.fill", sortOrder: 1)
        context.insert(food)
        context.insert(transport)
        let expenses = [
            Expense(amount: 5, category: food),
            Expense(amount: 20, category: transport),
            Expense(amount: 8, category: food),
            Expense(amount: 3),
            Expense(amount: 4),
        ]
        expenses.forEach(context.insert)

        let totals = SpendingStatistics.categoryTotals(expenses)

        #expect(totals.map(\.category?.name) == ["Transporte", "Comida", nil])
        #expect(totals.map(\.total) == [20, 13, 7])
    }

    @Test func paymentMethodTotalsSkipMethodsWithoutSpending() {
        let expenses = [
            Expense(amount: 5, paymentMethod: .cash),
            Expense(amount: 12, paymentMethod: .card),
            Expense(amount: 1, paymentMethod: .cash),
        ]

        let totals = SpendingStatistics.paymentMethodTotals(expenses)

        #expect(totals.map(\.paymentMethod) == [.card, .cash])
        #expect(totals.map(\.total) == [12, 6])
    }

    @Test func monthlyTotalsIncludeEmptyMonthsInChronologicalOrder() throws {
        let expenses = [
            Expense(amount: 10, date: try date(2026, 1, 5)),
            Expense(amount: 3, date: try date(2026, 3, 31)),
            Expense(amount: 4, date: try date(2026, 3, 2)),
            Expense(amount: 99, date: try date(2025, 12, 31)),
        ]

        let totals = SpendingStatistics.monthlyTotals(expenses, endingInMonthOf: try date(2026, 3, 15), count: 3)

        #expect(totals.map(\.monthStart) == [try date(2026, 1, 1), try date(2026, 2, 1), try date(2026, 3, 1)])
        #expect(totals.map(\.total) == [10, 0, 7])
    }

    @Test func elapsedDaysDependsOnTheMonth() throws {
        let now = try date(2026, 3, 15, hour: 10)
        #expect(SpendingStatistics.elapsedDays(inMonthOf: try date(2026, 3, 2), now: now) == 15)
        #expect(SpendingStatistics.elapsedDays(inMonthOf: try date(2026, 2, 2), now: now) == 28)
        #expect(SpendingStatistics.elapsedDays(inMonthOf: try date(2026, 4, 2), now: now) == 0)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) throws -> Date {
        try #require(DateComponents(calendar: .current, year: year, month: month, day: day, hour: hour, minute: minute).date)
    }
}
