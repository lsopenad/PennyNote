import Foundation
import SwiftData

// Plantilla de un gasto que se repite. No es un gasto: RecurringExpenseGenerator crea a partir de ella
// un Expense normal cada vez que llega nextDate.
@Model
final class RecurringExpense {
    var id: UUID
    var amount: Decimal
    var title: String
    // PaymentMethod.rawValue, como en Expense.
    private(set) var storedPaymentMethod: String
    // RecurrenceFrequency.rawValue.
    private(set) var storedFrequency: String
    var category: ExpenseCategory?

    // Primera repetición de la serie. Las demás se calculan sumando semanas, meses o años a esta
    // fecha, y no a la anterior, para que un día 31 vuelva al 31 tras pasar por el 28 de febrero.
    var startDate: Date
    // Siguiente repetición que falta por crear.
    var nextDate: Date
    var isPaused: Bool

    var createdAt: Date
    // Contabilidad de la sincronización, como en Expense.
    var localLastModified: Date
    var syncStatus: SyncStatus
    var isSoftDeleted: Bool

    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: storedPaymentMethod) ?? .other }
        set { storedPaymentMethod = newValue.rawValue }
    }

    // Con un código desconocido (de una versión futura) se trata como mensual.
    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: storedFrequency) ?? .monthly }
        set { storedFrequency = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        amount: Decimal,
        title: String = "",
        paymentMethod: PaymentMethod = .card,
        category: ExpenseCategory? = nil,
        frequency: RecurrenceFrequency,
        startDate: Date,
        nextDate: Date
    ) {
        self.id = id
        self.amount = amount
        self.title = title
        self.storedPaymentMethod = paymentMethod.rawValue
        self.storedFrequency = frequency.rawValue
        self.category = category
        self.startDate = startDate
        self.nextDate = nextDate
        self.isPaused = false
        self.createdAt = .now
        self.localLastModified = .now
        self.syncStatus = .pending
        self.isSoftDeleted = false
    }
}
