import Foundation
import SwiftData
import Testing
@testable import PennyNote

@MainActor
struct ExpenseRepositoryTests {
    private let context: ModelContext
    private let recorder: RecordingRepositoryEffects

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, RecurringExpense.self, configurations: configuration)
        context = ModelContext(container)
        recorder = try RecordingRepositoryEffects()
    }

    // Los gastos y los recurrentes de la categoría borrada pasan a la de reserva y quedan pendientes de
    // subir; el borrado de la categoría queda apuntado para sincronizarlo.
    @Test func deletingACategoryMovesItsExpensesAndRecurringToTheFallback() throws {
        let otros = insertCategory("Otros")
        let comida = insertCategory("Comida")
        let comidaID = comida.id
        let expense = insertSyncedExpense(category: comida)
        let recurringExpense = insertSyncedRecurringExpense(category: comida)
        try context.save()

        let deleted = ExpenseRepository.deleteCategory(comida, context: context, effects: recorder.effects)

        #expect(deleted)
        #expect(expense.category === otros)
        #expect(expense.syncStatus == .pending)
        #expect(recurringExpense.category === otros)
        #expect(recurringExpense.syncStatus == .pending)
        #expect(try context.fetch(FetchDescriptor<ExpenseCategory>()).map(\.id) == [otros.id])
        let tombstone = try #require(recorder.syncState.categoryTombstones.first)
        #expect(recorder.syncState.categoryTombstones.count == 1)
        #expect(tombstone.id == comidaID)
        #expect(tombstone.isDeleted)
    }

    // Si se borra la propia categoría de reserva, sus gastos pasan a otra de las que quedan.
    @Test func deletingTheFallbackCategoryMovesItsExpensesToAnotherOne() throws {
        let otros = insertCategory("Otros")
        let comida = insertCategory("Comida")
        let expense = insertSyncedExpense(category: otros)
        try context.save()

        ExpenseRepository.deleteCategory(otros, context: context, effects: recorder.effects)

        #expect(expense.category === comida)
    }

    @Test func theLastCategoryCannotBeDeleted() throws {
        let comida = insertCategory("Comida")
        let expense = insertSyncedExpense(category: comida)
        try context.save()

        let deleted = ExpenseRepository.deleteCategory(comida, context: context, effects: recorder.effects)

        #expect(!deleted)
        #expect(try context.fetch(FetchDescriptor<ExpenseCategory>()).map(\.id) == [comida.id])
        #expect(expense.category === comida)
        #expect(recorder.syncState.categoryTombstones.isEmpty)
        #expect(recorder.widgetRefreshCount == 0)
        #expect(recorder.syncRequestCount == 0)
    }

    @Test func writesRefreshTheWidgetAndRequestASync() {
        ExpenseRepository.addExpense(amount: 12, date: .now, category: nil, context: context, effects: recorder.effects)

        #expect(recorder.widgetRefreshCount == 1)
        #expect(recorder.syncRequestCount == 1)
    }

    // Es el comportamiento actual: una categoría nueva aún no tiene gastos que mostrar en el widget.
    @Test func addingACategoryRequestsASyncWithoutRefreshingTheWidget() {
        ExpenseRepository.addCategory(name: "Viajes", icon: .fallback, color: nil, context: context, effects: recorder.effects)

        #expect(recorder.syncRequestCount == 1)
        #expect(recorder.widgetRefreshCount == 0)
    }

    // MARK: - Utilidades

    private func insertCategory(_ name: String) -> ExpenseCategory {
        let category = ExpenseCategory(name: name, icon: .init(symbolName: "tag"), sortOrder: 0)
        category.syncStatus = .synced
        context.insert(category)
        return category
    }

    private func insertSyncedExpense(category: ExpenseCategory) -> Expense {
        let expense = Expense(amount: 23.4, date: .now, title: "Mercadona", paymentMethod: .cash, category: category)
        expense.syncStatus = .synced
        context.insert(expense)
        return expense
    }

    private func insertSyncedRecurringExpense(category: ExpenseCategory) -> RecurringExpense {
        let recurringExpense = RecurringExpense(
            amount: 9.99,
            title: "Netflix",
            category: category,
            frequency: .monthly,
            startDate: .now,
            nextDate: .now.addingTimeInterval(30 * 86_400)
        )
        recurringExpense.syncStatus = .synced
        context.insert(recurringExpense)
        return recurringExpense
    }
}
