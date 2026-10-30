import Foundation
import SwiftData
import Testing
@testable import PennyNote

@MainActor
struct RecurringExpenseTests {
    private let context: ModelContext
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, RecurringExpense.self, configurations: configuration)
        context = ModelContext(container)
    }

    // MARK: - Fechas

    @Test func monthlyOnThe31stFallsOnLastDayWithoutDrifting() {
        let schedule = RecurrenceSchedule(frequency: .monthly, startDate: date(2026, 1, 31), calendar: calendar)

        let days = (0...4).compactMap { schedule.occurrence($0) }.map(dayString)

        #expect(days == ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30", "2026-05-31"])
    }

    @Test func yearlyOnLeapDayFallsOnFebruary28th() {
        let schedule = RecurrenceSchedule(frequency: .yearly, startDate: date(2028, 2, 29), calendar: calendar)

        #expect(schedule.occurrence(1).map(dayString) == "2029-02-28")
        #expect(schedule.occurrence(4).map(dayString) == "2032-02-29")
    }

    @Test func weeklyKeepsTheWeekday() {
        let schedule = RecurrenceSchedule(frequency: .weekly, startDate: date(2026, 10, 5), calendar: calendar)

        #expect(schedule.occurrence(after: date(2026, 10, 20)).map(dayString) == "2026-10-26")
    }

    @Test func occurrenceAfterSkipsTheGivenDate() {
        let schedule = RecurrenceSchedule(frequency: .monthly, startDate: date(2026, 1, 31), calendar: calendar)

        #expect(schedule.occurrence(after: date(2026, 2, 28)).map(dayString) == "2026-03-31")
        #expect(schedule.firstOccurrence(onOrAfterDayOf: date(2026, 4, 30, hour: 23)).map(dayString) == "2026-04-30")
        #expect(schedule.firstOccurrence(onOrAfterDayOf: date(2026, 5, 1)).map(dayString) == "2026-05-31")
    }

    // MARK: - Generador

    @Test func createsMissedExpensesUpToTodayButNotFuture() throws {
        let template = insertTemplate(start: date(2026, 7, 5), next: date(2026, 8, 5))

        let created = RecurringExpenseGenerator.generateDueExpenses(context: context, now: date(2026, 10, 30), calendar: calendar)

        #expect(created == 3)
        let days = try fetchExpenses().map(\.date).sorted().map(dayString)
        #expect(days == ["2026-08-05", "2026-09-05", "2026-10-05"])
        #expect(dayString(template.nextDate) == "2026-11-05")
        #expect(template.syncStatus == .pending)
        #expect(try fetchExpenses().allSatisfy { $0.recurringExpenseID == template.id && $0.amount == 12.99 })
    }

    @Test func createsTodaysExpenseEvenIfItsTimeHasNotCome() throws {
        insertTemplate(start: date(2026, 10, 30, hour: 20), next: date(2026, 10, 30, hour: 20))

        let created = RecurringExpenseGenerator.generateDueExpenses(context: context, now: date(2026, 10, 30, hour: 9), calendar: calendar)

        #expect(created == 1)
    }

    @Test func runningAgainCreatesNothing() {
        insertTemplate(start: date(2026, 9, 5), next: date(2026, 9, 5))
        RecurringExpenseGenerator.generateDueExpenses(context: context, now: date(2026, 10, 30), calendar: calendar)

        let created = RecurringExpenseGenerator.generateDueExpenses(context: context, now: date(2026, 10, 30), calendar: calendar)

        #expect(created == 0)
    }

    @Test func pausedAndDeletedTemplatesCreateNothing() throws {
        insertTemplate(start: date(2026, 9, 5), next: date(2026, 9, 5)).isPaused = true
        insertTemplate(start: date(2026, 9, 5), next: date(2026, 9, 5)).isSoftDeleted = true

        RecurringExpenseGenerator.generateDueExpenses(context: context, now: date(2026, 10, 30), calendar: calendar)

        #expect(try fetchExpenses().isEmpty)
    }

    @Test func expenseAlreadyCreatedByAnotherPhoneIsNotDuplicated() throws {
        let template = insertTemplate(start: date(2026, 10, 5), next: date(2026, 10, 5))
        let id = RecurringExpenseGenerator.expenseID(for: template, on: date(2026, 10, 5), calendar: calendar)
        context.insert(Expense(id: id, amount: 12.99, recurringExpenseID: template.id))

        let created = RecurringExpenseGenerator.generateDueExpenses(context: context, now: date(2026, 10, 30), calendar: calendar)

        #expect(created == 0)
        #expect(try fetchExpenses().count == 1)
        #expect(dayString(template.nextDate) == "2026-11-05")
    }

    @Test func generatedIDsAreStablePerTemplateAndDay() {
        let template = insertTemplate(start: date(2026, 10, 5), next: date(2026, 10, 5))
        let other = insertTemplate(start: date(2026, 10, 5), next: date(2026, 10, 5))

        let morning = RecurringExpenseGenerator.expenseID(for: template, on: date(2026, 10, 5, hour: 8), calendar: calendar)
        let evening = RecurringExpenseGenerator.expenseID(for: template, on: date(2026, 10, 5, hour: 21), calendar: calendar)

        #expect(morning == evening)
        #expect(morning != RecurringExpenseGenerator.expenseID(for: template, on: date(2026, 11, 5), calendar: calendar))
        #expect(morning != RecurringExpenseGenerator.expenseID(for: other, on: date(2026, 10, 5), calendar: calendar))
    }

    @Test func nameBasedUUIDMatchesRFCExample() throws {
        // Ejemplo de RFC 9562 (A.4): espacio de nombres DNS y "www.example.com".
        let dns = try #require(UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8"))

        #expect(UUID(nameBased: "www.example.com", namespace: dns).uuidString == "2ED6657D-E927-568B-95E1-2665A8AEA6A2")
    }

    // MARK: - Editar

    @Test func makingAnOldExpenseRecurringFillsUpToToday() throws {
        let start = try #require(Calendar.current.date(byAdding: .month, value: -3, to: .now))

        ExpenseRepository.addExpense(amount: 9.99, date: start, title: "Netflix", category: nil, repeatFrequency: .monthly, context: context)

        let template = try #require(try context.fetch(FetchDescriptor<RecurringExpense>()).first)
        let expenses = try fetchExpenses()
        #expect(expenses.count == 4)
        #expect(expenses.allSatisfy { $0.recurringExpenseID == template.id && $0.title == "Netflix" })
        #expect(template.nextDate > .now)
        #expect(template.startDate == start)
    }

    @Test func resumingSkipsWhatWasDueWhilePaused() throws {
        let template = insertTemplate(start: date(2026, 1, 31), next: date(2026, 2, 28))
        template.isPaused = true

        update(template, nextDate: template.nextDate, isPaused: false, now: date(2026, 4, 10))

        #expect(try fetchExpenses().isEmpty)
        #expect(dayString(template.nextDate) == "2026-04-30")
        // La serie sigue anclada al 31.
        #expect(dayString(template.startDate) == "2026-01-31")
    }

    @Test func changingTheNextDateRestartsTheSeries() {
        let template = insertTemplate(start: date(2026, 1, 31), next: date(2026, 11, 30))

        update(template, nextDate: date(2026, 11, 15), isPaused: false, now: date(2026, 10, 30))

        #expect(dayString(template.startDate) == "2026-11-15")
        #expect(dayString(template.nextDate) == "2026-11-15")
    }

    @Test func deletingTemplateKeepsItsExpenses() throws {
        let template = insertTemplate(start: date(2026, 9, 5), next: date(2026, 9, 5))
        RecurringExpenseGenerator.generateDueExpenses(context: context, now: date(2026, 10, 30), calendar: calendar)

        ExpenseRepository.deleteRecurringExpense(template, context: context)

        #expect(template.isSoftDeleted)
        #expect(try fetchExpenses().count == 2)
    }

    // MARK: - Utilidades

    @discardableResult
    private func insertTemplate(start: Date, next: Date) -> RecurringExpense {
        let template = RecurringExpense(amount: 12.99, title: "Netflix", frequency: .monthly, startDate: start, nextDate: next)
        template.syncStatus = .synced
        context.insert(template)
        return template
    }

    private func update(_ template: RecurringExpense, nextDate: Date, isPaused: Bool, now: Date) {
        ExpenseRepository.updateRecurringExpense(
            template,
            amount: template.amount,
            title: template.title,
            paymentMethod: template.paymentMethod,
            category: template.category,
            frequency: template.frequency,
            nextDate: nextDate,
            isPaused: isPaused,
            now: now,
            calendar: calendar,
            context: context
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func dayString(_ date: Date) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year!, day.month!, day.day!)
    }

    private func fetchExpenses() throws -> [Expense] {
        try context.fetch(FetchDescriptor<Expense>())
    }
}
