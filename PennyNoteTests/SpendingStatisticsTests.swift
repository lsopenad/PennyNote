import Foundation
import SwiftData
import Testing
@testable import PennyNote

@MainActor
struct SpendingStatisticsTests {
    private let context: ModelContext

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, RecurringExpense.self, configurations: configuration)
        context = ModelContext(container)
    }

    @Test func monthSpendingBucketsByDayAndIgnoresOtherMonthsAndDeleted() throws {
        let deleted = Expense(amount: 100, date: try date(2026, 3, 10))
        deleted.isSoftDeleted = true
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
        let march = StatisticsPeriod(kind: .month, containing: try date(2026, 3, 15))

        let totals = SpendingStatistics.periodTotals(expenses, endingIn: march, count: 3)

        #expect(totals.map(\.period.start) == [try date(2026, 1, 1), try date(2026, 2, 1), try date(2026, 3, 1)])
        #expect(totals.map(\.total) == [10, 0, 7])
    }

    @Test func weeklyTotalsCountWeeksThatCrossMonths() throws {
        let expenses = [
            Expense(amount: 5, date: try date(2026, 10, 31)),
            Expense(amount: 2, date: try date(2026, 11, 1, hour: 23)),
            Expense(amount: 8, date: try date(2026, 11, 2)),
        ]
        let week = StatisticsPeriod(kind: .week, containing: try date(2026, 11, 4), calendar: mondayCalendar)

        let totals = SpendingStatistics.periodTotals(expenses, endingIn: week, count: 2, calendar: mondayCalendar)

        #expect(totals.map(\.period.start) == [try date(2026, 10, 26), try date(2026, 11, 2)])
        #expect(totals.map(\.total) == [7, 8])
    }

    @Test func elapsedDaysDependsOnThePeriod() throws {
        let now = try date(2026, 3, 15, hour: 10)
        func elapsed(_ kind: StatisticsPeriod.Kind, _ date: Date) -> Int {
            SpendingStatistics.elapsedDays(in: StatisticsPeriod(kind: kind, containing: date, calendar: mondayCalendar), now: now, calendar: mondayCalendar)
        }
        #expect(elapsed(.month, try date(2026, 3, 2)) == 15)
        #expect(elapsed(.month, try date(2026, 2, 2)) == 28)
        #expect(elapsed(.month, try date(2026, 4, 2)) == 0)
        // El 15 de marzo de 2026 es domingo: la semana del lunes 9 ya ha empezado entera.
        #expect(elapsed(.week, try date(2026, 3, 12)) == 7)
        #expect(elapsed(.week, try date(2026, 3, 16)) == 0)
        #expect(elapsed(.day, try date(2026, 3, 15)) == 1)
    }

    @Test func dailyTotalsFollowTheDaysOfTheWeek() throws {
        let week = StatisticsPeriod(kind: .week, containing: try date(2026, 10, 29), calendar: mondayCalendar)
        let expenses = [
            Expense(amount: 3, date: try date(2026, 10, 26, hour: 9)),
            Expense(amount: 4, date: try date(2026, 11, 1, hour: 20)),
            Expense(amount: 50, date: try date(2026, 11, 2)),
        ]

        let totals = SpendingStatistics.dailyTotals(expenses, in: week, calendar: mondayCalendar)

        #expect(totals == [3, 0, 0, 0, 0, 0, 4])
    }

    @Test func latestPeriodReachesFutureExpensesButNotDeletedOnes() throws {
        let now = try date(2026, 10, 29)
        let deleted = Expense(amount: 1, date: try date(2027, 3, 1))
        deleted.isSoftDeleted = true
        func latest(_ kind: StatisticsPeriod.Kind, _ expenses: [Expense]) -> Date {
            SpendingStatistics.latestPeriod(kind, expenses: expenses, now: now, calendar: mondayCalendar).start
        }

        #expect(latest(.month, []) == (try date(2026, 10, 1)))
        #expect(latest(.month, [Expense(amount: 1, date: try date(2026, 5, 3))]) == (try date(2026, 10, 1)))
        #expect(latest(.month, [Expense(amount: 1, date: try date(2026, 12, 24)), deleted]) == (try date(2026, 12, 1)))
        #expect(latest(.week, [Expense(amount: 1, date: try date(2026, 12, 24))]) == (try date(2026, 12, 21)))
        #expect(latest(.day, []) == (try date(2026, 10, 29)))
    }

    @Test func switchingKindKeepsTodayOrTheFirstDay() throws {
        let now = try date(2026, 10, 29, hour: 12)
        let october = StatisticsPeriod(kind: .month, containing: now, calendar: mondayCalendar)
        let august = StatisticsPeriod(kind: .month, containing: try date(2026, 8, 20), calendar: mondayCalendar)

        #expect(october.converted(to: .week, now: now, calendar: mondayCalendar).start == (try date(2026, 10, 26)))
        #expect(august.converted(to: .week, now: now, calendar: mondayCalendar).start == (try date(2026, 7, 27)))
        #expect(august.converted(to: .day, now: now, calendar: mondayCalendar).start == (try date(2026, 8, 1)))
        let weekOfJuly = StatisticsPeriod(kind: .week, containing: try date(2026, 7, 29), calendar: mondayCalendar)
        #expect(weekOfJuly.converted(to: .month, now: now, calendar: mondayCalendar).start == (try date(2026, 7, 1)))
    }

    // El 25 de octubre de 2026 se atrasa la hora en Madrid: ese domingo dura 25 horas.
    @Test func weekWithTheDaylightSavingChangeHasSevenDays() throws {
        let calendar = try calendar("Europe/Madrid", firstWeekday: 2)
        let week = StatisticsPeriod(kind: .week, containing: try date(2026, 10, 22, in: calendar), calendar: calendar)
        let expenses = [
            Expense(amount: 1, date: try date(2026, 10, 19, in: calendar)),
            Expense(amount: 2, date: try date(2026, 10, 25, hour: 2, minute: 30, in: calendar)),
            Expense(amount: 3, date: try date(2026, 10, 25, hour: 23, minute: 30, in: calendar)),
            Expense(amount: 50, date: try date(2026, 10, 26, in: calendar)),
        ]

        #expect(week.days(calendar: calendar).count == 7)
        #expect(week.start == (try date(2026, 10, 19, in: calendar)))
        #expect(SpendingStatistics.dailyTotals(expenses, in: week, calendar: calendar) == [1, 0, 0, 0, 0, 0, 5])
        #expect(SpendingStatistics.elapsedDays(in: week, now: try date(2026, 10, 25, hour: 23, in: calendar), calendar: calendar) == 7)
    }

    // En Nueva York la hora cambia el domingo 1 de noviembre, que allí es el primer día de la semana.
    @Test func sundayFirstWeeksStartOnSundayAcrossTheDaylightSavingChange() throws {
        let calendar = try calendar("America/New_York", firstWeekday: 1)
        let week = StatisticsPeriod(kind: .week, containing: try date(2026, 11, 4, in: calendar), calendar: calendar)
        let expenses = [
            Expense(amount: 4, date: try date(2026, 10, 31, hour: 23, in: calendar)),
            Expense(amount: 6, date: try date(2026, 11, 1, hour: 1, minute: 30, in: calendar)),
            Expense(amount: 7, date: try date(2026, 11, 7, hour: 23, minute: 59, in: calendar)),
        ]

        let totals = SpendingStatistics.periodTotals(expenses, endingIn: week, count: 2, calendar: calendar)

        #expect(week.days(calendar: calendar).count == 7)
        #expect(totals.map(\.period.start) == [try date(2026, 10, 25, in: calendar), try date(2026, 11, 1, in: calendar)])
        #expect(totals.map(\.total) == [4, 13])
        #expect(SpendingStatistics.dailyTotals(expenses, in: week, calendar: calendar) == [6, 0, 0, 0, 0, 0, 7])
    }

    // El 29 de marzo de 2026 se adelanta la hora en Madrid: ese día dura 23 horas.
    @Test func monthWithTheDaylightSavingChangeKeepsEveryDay() throws {
        let calendar = try calendar("Europe/Madrid", firstWeekday: 2)
        let expenses = [
            Expense(amount: 2, date: try date(2026, 3, 29, hour: 3, in: calendar)),
            Expense(amount: 3, date: try date(2026, 3, 31, hour: 23, minute: 59, in: calendar)),
        ]
        let month = StatisticsPeriod(kind: .month, containing: try date(2026, 3, 15, in: calendar), calendar: calendar)

        let spending = SpendingStatistics.monthSpending(expenses, monthOf: try date(2026, 3, 15, in: calendar), calendar: calendar)

        #expect(spending.dailyTotals.count == 31)
        #expect(spending.dailyTotals[28] == 2)
        #expect(spending.dailyTotals[30] == 3)
        #expect(SpendingStatistics.dailyTotals(expenses, in: month, calendar: calendar) == spending.dailyTotals)
    }

    private func calendar(_ timeZoneID: String, firstWeekday: Int) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: timeZoneID))
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0, in calendar: Calendar) throws -> Date {
        try #require(DateComponents(calendar: calendar, year: year, month: month, day: day, hour: hour, minute: minute).date)
    }

    // Semanas de lunes a domingo, como en España, sea cual sea la región del simulador.
    private var mondayCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) throws -> Date {
        try #require(DateComponents(calendar: .current, year: year, month: month, day: day, hour: hour, minute: minute).date)
    }
}
