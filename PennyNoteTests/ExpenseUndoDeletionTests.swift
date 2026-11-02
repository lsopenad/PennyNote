import Foundation
import SwiftData
import Testing
@testable import PennyNote

@MainActor
struct ExpenseUndoDeletionTests {
    private let context: ModelContext

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, RecurringExpense.self, configurations: configuration)
        context = ModelContext(container)
    }

    @Test func restoresExpenseStillOnThePhone() throws {
        let expense = insertSyncedExpense(category: insertCategory("Comida"))

        let deleted = ExpenseRepository.deleteExpense(expense, context: context)
        let deletedAt = expense.localLastModified
        ExpenseRepository.restoreExpense(deleted, context: context)

        let restored = try #require(try fetchExpenses().first)
        #expect(restored === expense)
        #expect(!restored.isSoftDeleted)
        #expect(restored.syncStatus == .pending)
        #expect(restored.localLastModified >= deletedAt)
    }

    // La sincronización quita del móvil los borrados ya subidos: Deshacer tiene que crearlo de nuevo.
    @Test func recreatesExpenseRemovedBySync() throws {
        let category = insertCategory("Comida")
        let recurringExpenseID = UUID()
        let expense = insertSyncedExpense(category: category, recurringExpenseID: recurringExpenseID)
        let original = DeletedExpense(expense)

        let deleted = ExpenseRepository.deleteExpense(expense, context: context)
        let deletedAt = expense.localLastModified
        context.delete(expense)
        try context.save()
        ExpenseRepository.restoreExpense(deleted, context: context)

        let restored = try #require(try fetchExpenses().first)
        #expect(DeletedExpense(restored) == original)
        #expect(restored.category === category)
        #expect(!restored.isSoftDeleted)
        #expect(restored.syncStatus == .pending)
        #expect(restored.localLastModified >= deletedAt)
    }

    @Test func recreatedExpenseFallsBackWhenItsCategoryWasDeleted() throws {
        let fallback = insertCategory("Otros")
        let category = insertCategory("Comida")
        let expense = insertSyncedExpense(category: category)

        let deleted = ExpenseRepository.deleteExpense(expense, context: context)
        context.delete(expense)
        context.delete(category)
        try context.save()
        ExpenseRepository.restoreExpense(deleted, context: context)

        let restored = try #require(try fetchExpenses().first)
        #expect(restored.category === fallback)
    }

    @Test func displayNameFallsBackToTheCategory() {
        let category = insertCategory("Comida")

        #expect(DeletedExpense(insertSyncedExpense(title: "Mercadona", category: category)).displayName == "Mercadona")
        #expect(DeletedExpense(insertSyncedExpense(title: "", category: category)).displayName == "Comida")
    }

    // MARK: - Utilidades

    private func insertCategory(_ name: String) -> ExpenseCategory {
        let category = ExpenseCategory(name: name, icon: .init(symbolName: "tag"), sortOrder: 0)
        context.insert(category)
        return category
    }

    private func insertSyncedExpense(
        title: String = "Mercadona",
        category: ExpenseCategory?,
        recurringExpenseID: UUID? = nil
    ) -> Expense {
        let expense = Expense(
            amount: 23.4,
            date: .now.addingTimeInterval(-86_400),
            title: title,
            paymentMethod: .cash,
            category: category,
            recurringExpenseID: recurringExpenseID
        )
        expense.createdAt = .now.addingTimeInterval(-3_600)
        expense.syncStatus = .synced
        context.insert(expense)
        return expense
    }

    private func fetchExpenses() throws -> [Expense] {
        try context.fetch(FetchDescriptor<Expense>())
    }
}
