import Foundation
import SwiftData

@Model
final class Expense {
    var id: UUID
    var amount: Decimal
    var date: Date
    var title: String
    var paymentMethod: PaymentMethod
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
        self.paymentMethod = paymentMethod
        self.category = category
        self.createdAt = .now
        self.localLastModified = .now
        self.syncStatus = .pending
        self.isSoftDeleted = false
    }
}
