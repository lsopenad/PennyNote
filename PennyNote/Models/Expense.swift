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
    // Se actualiza en cada mutación local; es la base de la comparación last-write-wins.
    var localLastModified: Date

    // nil hasta que el primer push crea la página en Notion.
    var notionPageID: String?
    // Se guarda en cada push/pull pero la resolución de conflictos usa el lastEditedTime remoto recibido.
    var notionLastEditedTime: Date?
    var syncStatus: SyncStatus

    // Borrado lógico: se marca así hasta que el push archive la página en Notion.
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
        self.notionPageID = nil
        self.notionLastEditedTime = nil
        self.syncStatus = .pending
        self.isDeleted = false
    }
}
