import Foundation
import SwiftData

@Model
final class Expense {
    var id: UUID
    var amount: Decimal
    var date: Date
    // Valor por defecto obligatorio para la migración ligera: sin él, un almacén creado antes de
    // existir este campo no se puede abrir. No se usa originalName "note": haría que los almacenes
    // que ya tienen "title" perdieran su contenido al migrar.
    var title: String = ""

    // Opcional en disco porque la migración deja NULL en los gastos anteriores a este campo
    // (SwiftData no aplica el valor por defecto de un enum); leerlo como no opcional cierra la app.
    @Attribute(originalName: "paymentMethod") private var storedPaymentMethod: PaymentMethod?

    var paymentMethod: PaymentMethod {
        get { storedPaymentMethod ?? .card }
        set { storedPaymentMethod = newValue }
    }
    var category: ExpenseCategory?

    var createdAt: Date
    // Contabilidad de la sincronización con Supabase: localLastModified decide qué versión gana
    // (last-write-wins) y syncStatus marca lo pendiente de subir.
    var localLastModified: Date
    var syncStatus: SyncStatus

    // Borrado lógico: el gasto se oculta pero se conserva hasta que el borrado llega al servidor.
    // No puede llamarse isDeleted: ese nombre es de PersistentModel, y SwiftData lo restablece al
    // guardar (un gasto borrado volvía a false). originalName mantiene la columna que ya hay en disco.
    @Attribute(originalName: "isDeleted") var isSoftDeleted: Bool

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
        self.storedPaymentMethod = paymentMethod
        self.category = category
        self.createdAt = .now
        self.localLastModified = .now
        self.syncStatus = .pending
        self.isSoftDeleted = false
    }
}
