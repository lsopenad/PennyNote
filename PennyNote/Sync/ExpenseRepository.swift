import Foundation
import SwiftData

// Único punto de escritura de la app (Views y LogExpenseIntent): evita duplicar en cada sitio
// la lógica de "guardar + marcar pending + recalcular total + programar sync".
@MainActor
enum ExpenseRepository {
    static func addExpense(amount: Decimal, date: Date, note: String, category: ExpenseCategory?, context: ModelContext) {
        let expense = Expense(amount: amount, date: date, note: note, category: category)
        context.insert(expense)
        afterMutation(context: context)
    }

    static func updateExpense(
        _ expense: Expense,
        amount: Decimal,
        date: Date,
        note: String,
        category: ExpenseCategory?,
        context: ModelContext
    ) {
        expense.amount = amount
        expense.date = date
        expense.note = note
        expense.category = category
        expense.localLastModified = .now
        expense.syncStatus = .pending
        afterMutation(context: context)
    }

    static func deleteExpense(_ expense: Expense, context: ModelContext) {
        expense.isDeleted = true
        expense.localLastModified = .now
        expense.syncStatus = .pending
        afterMutation(context: context)
    }

    @discardableResult
    static func addCategory(name: String, symbolName: String, context: ModelContext) -> ExpenseCategory {
        let existing = (try? context.fetch(FetchDescriptor<ExpenseCategory>())) ?? []
        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let category = ExpenseCategory(name: name, symbolName: symbolName, sortOrder: nextOrder)
        context.insert(category)
        try? context.save()
        Task { await SyncEngine.shared.pushCategorySchema() }
        return category
    }

    // false si no se puede borrar (es la última categoría restante).
    @discardableResult
    static func deleteCategory(_ category: ExpenseCategory, context: ModelContext) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<ExpenseCategory>())) ?? []
        guard all.count > 1 else { return false }

        let fallback = SeedDataService.fallbackCategory(context: context) ?? all.first { $0 !== category }
        for expense in category.expenses {
            expense.category = fallback
            expense.localLastModified = .now
            expense.syncStatus = .pending
        }
        context.delete(category)
        try? context.save()
        Task { await SyncEngine.shared.pushCategorySchema() }
        return true
    }

    private static func afterMutation(context: ModelContext) {
        let total = MonthlyTotalCalculator.total(in: context)
        let monthStart = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
        MonthlyTotalStore.write(total: total, monthStart: monthStart)
        SyncTrigger.shared.scheduleDebouncedSync()
    }
}
