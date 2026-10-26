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

    // Se rellena al crear el gasto pero aún no se lee en ningún sitio.
    var createdAt: Date
    // Contabilidad de sincronización. Sin servidor no se usa, pero se conserva para la sync con
    // Supabase: localLastModified será la base del last-write-wins y syncStatus marca lo pendiente
    // de subir. Quitarlos ahora obligaría a otra migración al volver a añadirlos.
    var localLastModified: Date
    var syncStatus: SyncStatus

    // Borrado lógico: el gasto se oculta pero se conserva para poder propagar el borrado al servidor.
    var isDeleted: Bool

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
        self.isDeleted = false
    }
}
