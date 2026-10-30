import Foundation
import SwiftData

// Crea los gastos de las plantillas recurrentes a los que ya les ha llegado el día, incluidos los
// atrasados si la app llevaba tiempo sin abrirse. Nunca crea gastos de días futuros.
@MainActor
enum RecurringExpenseGenerator {
    // Tope por plantilla y pasada, por si una fecha de inicio absurda (años atrás, cada semana)
    // pretendiera crear miles de gastos de golpe. El resto se crea en las siguientes pasadas.
    static let maxExpensesPerTemplate = 500

    // Devuelve cuántos gastos ha creado. No guarda: lo hace quien llama.
    @discardableResult
    static func generateDueExpenses(context: ModelContext, now: Date = .now, calendar: Calendar = .current) -> Int {
        let templates = context.fetchOrEmpty(
            FetchDescriptor<RecurringExpense>(predicate: #Predicate { !$0.isSoftDeleted && !$0.isPaused }),
            failureMessage: "Fallo al leer los gastos recurrentes para crear sus gastos"
        )
        guard let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return 0 }

        var createdCount = 0
        for template in templates where template.nextDate < endOfToday {
            let schedule = RecurrenceSchedule(frequency: template.frequency, startDate: template.startDate, calendar: calendar)
            let existingIDs = expenseIDs(of: template, context: context)
            var generated = 0
            while template.nextDate < endOfToday, generated < maxExpensesPerTemplate {
                let date = template.nextDate
                let id = expenseID(for: template, on: date, calendar: calendar)
                // Ya creado por otro móvil (y bajado) o en una pasada anterior que no llegó a avanzar la fecha.
                if !existingIDs.contains(id) {
                    let expense = Expense(
                        id: id,
                        amount: template.amount,
                        date: date,
                        title: template.title,
                        paymentMethod: template.paymentMethod,
                        category: template.category,
                        recurringExpenseID: template.id
                    )
                    // Como versión, el inicio de su día y no «ahora»: si otro móvil ya lo creó y lo
                    // borraron o editaron, ese cambio es posterior y gana (last-write-wins), así que
                    // un móvil que lo vuelve a crear con la plantilla atrasada no lo resucita.
                    expense.localLastModified = calendar.startOfDay(for: date)
                    context.insert(expense)
                    createdCount += 1
                }
                generated += 1
                guard let next = schedule.occurrence(after: date) else { break }
                template.nextDate = next
            }
            template.markPendingSync()
        }
        if createdCount > 0 {
            Log.data.notice("Creados \(createdCount) gastos de gastos recurrentes")
        }
        return createdCount
    }

    // El mismo en todos los móviles: si dos crean a la vez el gasto de un día, en el servidor es una
    // sola fila y no un duplicado.
    static func expenseID(for template: RecurringExpense, on date: Date, calendar: Calendar) -> UUID {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let name = String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
        return UUID(nameBased: name, namespace: template.id)
    }

    private static func expenseIDs(of template: RecurringExpense, context: ModelContext) -> Set<UUID> {
        let templateID: UUID? = template.id
        let expenses = context.fetchOrEmpty(
            FetchDescriptor<Expense>(predicate: #Predicate { $0.recurringExpenseID == templateID }),
            failureMessage: "Fallo al leer los gastos de un gasto recurrente"
        )
        return Set(expenses.map(\.id))
    }
}
