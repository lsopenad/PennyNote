import Foundation
import SwiftData

// Único punto de escritura de la app (Views y LogExpenseIntent): evita duplicar en cada sitio
// la lógica de "guardar + marcar pendiente de subir + recalcular el widget + sincronizar".
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
        let expense = Expense(
            amount: amount,
            date: date,
            title: ExpenseLimits.clampedTitle(title),
            paymentMethod: paymentMethod,
            category: category
        )
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
        expense.title = ExpenseLimits.clampedTitle(title)
        expense.paymentMethod = paymentMethod
        expense.category = category
        expense.markPendingSync()
        afterMutation(context: context)
    }

    static func deleteExpense(_ expense: Expense, context: ModelContext) {
        expense.isSoftDeleted = true
        expense.markPendingSync()
        afterMutation(context: context)
    }

    @discardableResult
    static func addCategory(name: String, symbolName: String, context: ModelContext) -> ExpenseCategory {
        let existing = context.categories(failureMessage: "Fallo al leer categorías existentes al añadir una categoría")
        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let color = CategoryColor.nextAvailable(excluding: existing.compactMap(\.color))
        let category = ExpenseCategory(
            name: ExpenseLimits.clampedCategoryName(name),
            symbolName: symbolName,
            sortOrder: nextOrder,
            color: color
        )
        context.insert(category)
        context.saveOrLog(failureMessage: "Fallo al guardar la nueva categoría")
        SyncCoordinator.shared.requestSync()
        return category
    }

    // false si no se puede borrar (es la última categoría restante).
    @discardableResult
    static func deleteCategory(_ category: ExpenseCategory, context: ModelContext) -> Bool {
        let all = context.categories(failureMessage: "Fallo al leer categorías existentes al borrar una categoría")
        guard all.count > 1 else { return false }

        // Si se borra la propia categoría de reserva, sus gastos pasan a otra de las que quedan.
        let preferredFallback = SeedDataService.fallbackCategory(context: context).flatMap { $0 === category ? nil : $0 }
        let fallback = preferredFallback ?? all.first { $0 !== category }
        for expense in category.expenses {
            expense.category = fallback
            expense.markPendingSync()
        }
        // La categoría desaparece de SwiftData ya; su borrado queda apuntado para subirlo.
        category.localLastModified = .now
        SyncStateStore.standard.addCategoryTombstone(RemoteCategory(category, isDeleted: true))
        context.delete(category)
        // Los gastos han cambiado de categoría: el widget muestra las categorías principales.
        afterMutation(context: context)
        return true
    }

    // El color marca como pendiente la categoría, no sus gastos.
    static func setColor(_ color: CategoryColor, for category: ExpenseCategory, context: ModelContext) {
        category.color = color
        category.markPendingSync()
        afterMutation(context: context)
    }

    // Guarda en el acto: un contexto creado a mano (LogExpenseIntent) no tiene autoguardado.
    private static func afterMutation(context: ModelContext) {
        context.saveOrLog(failureMessage: "Fallo al guardar un cambio")
        WidgetSnapshotRefresher.refresh(in: context)
        SyncCoordinator.shared.requestSync()
    }
}
