import Foundation
import SwiftData

// Único punto de escritura de la app (Views y LogExpenseIntent): evita duplicar en cada sitio
// la lógica de "guardar + marcar pending + recalcular total + programar sync".
@MainActor
enum ExpenseRepository {
    static func addExpense(
        amount: Decimal,
        date: Date,
        title: String = "",
        paymentMethod: PaymentMethod = .card,
        category: ExpenseCategory?,
        context: ModelContext
    ) {
        let expense = Expense(amount: amount, date: date, title: title, paymentMethod: paymentMethod, category: category)
        context.insert(expense)
        afterMutation(context: context)
    }

    static func updateExpense(
        _ expense: Expense,
        amount: Decimal,
        date: Date,
        title: String,
        paymentMethod: PaymentMethod,
        category: ExpenseCategory?,
        context: ModelContext
    ) {
        expense.amount = amount
        expense.date = date
        expense.title = title
        expense.paymentMethod = paymentMethod
        expense.category = category
        markPending(expense)
        afterMutation(context: context)
    }

    static func deleteExpense(_ expense: Expense, context: ModelContext) {
        expense.isDeleted = true
        markPending(expense)
        afterMutation(context: context)
    }

    @discardableResult
    static func addCategory(name: String, symbolName: String, context: ModelContext) -> ExpenseCategory {
        let existing = context.fetchOrEmpty(
            FetchDescriptor<ExpenseCategory>(),
            failureMessage: "Fallo al leer categorías existentes al añadir '\(name)'"
        )
        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let category = ExpenseCategory(name: name, symbolName: symbolName, sortOrder: nextOrder)
        context.insert(category)
        context.saveOrLog(failureMessage: "Fallo al guardar la nueva categoría '\(name)'")
        Task { await SyncEngine.shared.pushCategorySchema() }
        return category
    }

    // false si no se puede borrar (es la última categoría restante).
    @discardableResult
    static func deleteCategory(_ category: ExpenseCategory, context: ModelContext) -> Bool {
        let all = context.fetchOrEmpty(
            FetchDescriptor<ExpenseCategory>(),
            failureMessage: "Fallo al leer categorías existentes al borrar '\(category.name)'"
        )
        guard all.count > 1 else { return false }

        let fallback = SeedDataService.fallbackCategory(context: context) ?? all.first { $0 !== category }
        for expense in category.expenses {
            expense.category = fallback
            markPending(expense)
        }
        context.delete(category)
        context.saveOrLog(failureMessage: "Fallo al guardar tras borrar la categoría '\(category.name)'")
        Task { await SyncEngine.shared.pushCategorySchema() }
        return true
    }

    private static func markPending(_ expense: Expense) {
        expense.localLastModified = .now
        expense.syncStatus = .pending
    }

    private static func afterMutation(context: ModelContext) {
        MonthlyTotalCalculator.refreshSharedTotal(in: context)
        SyncTrigger.shared.scheduleDebouncedSync()
    }
}
