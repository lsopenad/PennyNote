import Foundation
import SwiftData

@Model
final class Expense {
    var id: UUID
    var amount: Decimal
    var date: Date
    var title: String
    // PaymentMethod.rawValue. Se guarda el texto y no el enum, como el color de las categorías, para
    // que un valor desconocido no impida leer el gasto. Sustituye a la columna paymentMethod del
    // esquema V1, que guardaba el nombre en español (ver PennyNoteMigrationPlan).
    private(set) var storedPaymentMethod: String = PaymentMethod.card.rawValue

    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: storedPaymentMethod) ?? PaymentMethod(legacyName: storedPaymentMethod) ?? .other }
        set { storedPaymentMethod = newValue.rawValue }
    }

    var category: ExpenseCategory?

    var createdAt: Date
    // Contabilidad de la sincronización con Supabase: localLastModified decide qué versión gana
    // (last-write-wins) y syncStatus marca lo pendiente de subir.
    var localLastModified: Date
    var syncStatus: SyncStatus

    // Borrado lógico: el gasto se oculta pero se conserva hasta que el borrado llega al servidor.
    // No puede llamarse isDeleted: ese nombre es de PersistentModel, y SwiftData lo restablece al
    // guardar (un gasto borrado volvía a false).
    var isSoftDeleted: Bool

    init(
        id: UUID = UUID(),
        amount: Decimal,
        date: Date = .now,
        title: String = "",
        paymentMethod: PaymentMethod = .card,
        category: ExpenseCategory? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.title = title
        self.storedPaymentMethod = paymentMethod.rawValue
        self.category = category
        self.createdAt = .now
        self.localLastModified = .now
        self.syncStatus = .pending
        self.isSoftDeleted = false
    }
}
