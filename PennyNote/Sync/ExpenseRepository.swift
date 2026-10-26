import Foundation
import SwiftData

// Único punto de escritura de la app (Views y LogExpenseIntent): evita duplicar en cada sitio
// la lógica de "guardar + marcar pending + recalcular el widget".
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
        expense.isSoftDeleted = true
        markPending(expense)
        afterMutation(context: context)
    }

    @discardableResult
    static func addCategory(name: String, symbolName: String, context: ModelContext) -> ExpenseCategory {
        let existing = context.fetchOrEmpty(
            FetchDescriptor<ExpenseCategory>(),
            failureMessage: "Fallo al leer categorías existentes al añadir una categoría"
        )
        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let color = CategoryColor.nextAvailable(excluding: existing.compactMap(\.color))
        let category = ExpenseCategory(name: name, symbolName: symbolName, sortOrder: nextOrder, color: color)
        context.insert(category)
        context.saveOrLog(failureMessage: "Fallo al guardar la nueva categoría")
        return category
    }

    // false si no se puede borrar (es la última categoría restante).
    @discardableResult
    static func deleteCategory(_ category: ExpenseCategory, context: ModelContext) -> Bool {
        let all = context.fetchOrEmpty(
            FetchDescriptor<ExpenseCategory>(),
            failureMessage: "Fallo al leer categorías existentes al borrar una categoría"
        )
        guard all.count > 1 else { return false }

        // Si se borra la propia categoría de reserva, sus gastos pasan a otra de las que quedan.
        let preferredFallback = SeedDataService.fallbackCategory(context: context).flatMap { $0 === category ? nil : $0 }
        let fallback = preferredFallback ?? all.first { $0 !== category }
        for expense in category.expenses {
            expense.category = fallback
            markPending(expense)
        }
        context.delete(category)
        context.saveOrLog(failureMessage: "Fallo al guardar tras borrar una categoría")
        // Los gastos han cambiado de categoría: el widget muestra las categorías principales.
        MonthlyTotalCalculator.refreshWidgetSnapshot(in: context)
        return true
    }

    // El color no marca nada como pendiente: es un dato de la categoría, no de sus gastos.
    static func setColor(_ color: CategoryColor, for category: ExpenseCategory, context: ModelContext) {
        category.color = color
        context.saveOrLog(failureMessage: "Fallo al guardar el color de la categoría")
        MonthlyTotalCalculator.refreshWidgetSnapshot(in: context)
    }

    private static func markPending(_ expense: Expense) {
        expense.localLastModified = .now
        expense.syncStatus = .pending
    }

    private static func afterMutation(context: ModelContext) {
        MonthlyTotalCalculator.refreshWidgetSnapshot(in: context)
    }
}
