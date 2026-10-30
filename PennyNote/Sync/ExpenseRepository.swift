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
        repeatFrequency: RecurrenceFrequency? = nil,
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
        if let repeatFrequency {
            makeRecurring(expense, frequency: repeatFrequency, context: context)
        }
        afterMutation(context: context)
    }

    static func updateExpense(
        _ expense: Expense,
        amount: Decimal,
        date: Date,
        title: String,
        paymentMethod: PaymentMethod,
        category: ExpenseCategory?,
        repeatFrequency: RecurrenceFrequency? = nil,
        context: ModelContext
    ) {
        expense.amount = amount
        expense.date = date
        expense.title = ExpenseLimits.clampedTitle(title)
        expense.paymentMethod = paymentMethod
        expense.category = category
        expense.markPendingSync()
        if let repeatFrequency {
            makeRecurring(expense, frequency: repeatFrequency, context: context)
        }
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
        // Los recurrentes también, para que sus próximos gastos no salgan sin categoría.
        for recurringExpense in category.recurringExpenses {
            recurringExpense.category = fallback
            recurringExpense.markPendingSync()
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

    // MARK: - Gastos recurrentes

    // Cambios en la plantilla: solo afectan a los gastos que se creen a partir de ahora. Cambiar la
    // frecuencia o la fecha del próximo hace que la serie empiece de nuevo en esa fecha. Al reanudarla
    // se sigue desde la próxima repetición, sin crear las que tocaban durante la pausa.
    static func updateRecurringExpense(
        _ recurringExpense: RecurringExpense,
        amount: Decimal,
        title: String,
        paymentMethod: PaymentMethod,
        category: ExpenseCategory?,
        frequency: RecurrenceFrequency,
        nextDate: Date,
        isPaused: Bool,
        now: Date = .now,
        calendar: Calendar = .current,
        context: ModelContext
    ) {
        let currentNextDate = recurringExpense.isPaused && !isPaused
            ? resumedNextDate(of: recurringExpense, now: now, calendar: calendar)
            : recurringExpense.nextDate
        // Al reanudar, tanto la fecha que tenía al pausarla como la propuesta al reanudar cuentan como
        // «sin cambios»: solo otra fecha reinicia la serie.
        let scheduleChanged = frequency != recurringExpense.frequency
            || (!calendar.isDate(nextDate, inSameDayAs: currentNextDate)
                && !calendar.isDate(nextDate, inSameDayAs: recurringExpense.nextDate))

        recurringExpense.amount = amount
        recurringExpense.title = ExpenseLimits.clampedTitle(title)
        recurringExpense.paymentMethod = paymentMethod
        recurringExpense.category = category
        recurringExpense.isPaused = isPaused
        if scheduleChanged {
            recurringExpense.frequency = frequency
            recurringExpense.startDate = nextDate
            recurringExpense.nextDate = nextDate
        } else {
            // Sin tocar la fecha de inicio: un día 31 que ahora cae en 30 tiene que volver al 31.
            recurringExpense.nextDate = currentNextDate
        }
        recurringExpense.markPendingSync()
        RecurringExpenseGenerator.generateDueExpenses(context: context, now: now, calendar: calendar)
        afterMutation(context: context)
    }

    // Próxima repetición al reanudar una serie en pausa: la de hoy o la siguiente.
    static func resumedNextDate(of recurringExpense: RecurringExpense, now: Date = .now, calendar: Calendar = .current) -> Date {
        let schedule = RecurrenceSchedule(
            frequency: recurringExpense.frequency,
            startDate: recurringExpense.startDate,
            calendar: calendar
        )
        return schedule.firstOccurrence(onOrAfterDayOf: now) ?? recurringExpense.nextDate
    }

    // Los gastos que ya creó se quedan como están.
    static func deleteRecurringExpense(_ recurringExpense: RecurringExpense, context: ModelContext) {
        recurringExpense.isSoftDeleted = true
        recurringExpense.markPendingSync()
        afterMutation(context: context)
    }

    // El gasto es la primera repetición de la serie; las siguientes, hasta hoy, se crean en el acto.
    private static func makeRecurring(_ expense: Expense, frequency: RecurrenceFrequency, context: ModelContext) {
        let schedule = RecurrenceSchedule(frequency: frequency, startDate: expense.date)
        guard let nextDate = schedule.occurrence(1) else { return }
        let recurringExpense = RecurringExpense(
            amount: expense.amount,
            title: expense.title,
            paymentMethod: expense.paymentMethod,
            category: expense.category,
            frequency: frequency,
            startDate: expense.date,
            nextDate: nextDate
        )
        context.insert(recurringExpense)
        expense.recurringExpenseID = recurringExpense.id
        expense.markPendingSync()
        RecurringExpenseGenerator.generateDueExpenses(context: context)
    }

    // Guarda en el acto: un contexto creado a mano (LogExpenseIntent) no tiene autoguardado.
    private static func afterMutation(context: ModelContext) {
        context.saveOrLog(failureMessage: "Fallo al guardar un cambio")
        WidgetSnapshotRefresher.refresh(in: context)
        SyncCoordinator.shared.requestSync()
    }
}
