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
    // Plantilla que lo creó, si viene de un gasto recurrente. Es solo el id y no una relación: la
    // plantilla puede borrarse o no haber llegado aún a este móvil, y el gasto sigue igual.
    var recurringExpenseID: UUID?

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
        category: ExpenseCategory? = nil,
        recurringExpenseID: UUID? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.title = title
        self.storedPaymentMethod = paymentMethod.rawValue
        self.category = category
        self.recurringExpenseID = recurringExpenseID
        self.createdAt = .now
        self.localLastModified = .now
        self.syncStatus = .pending
        self.isSoftDeleted = false
    }
}

extension Expense {
    // Gasto pendiente de completar: sin categoría ni título, como los que crea el gasto rápido
    // (QuickExpenseIntent). Se deduce en vez de guardarse para no cambiar el esquema ni el servidor.
    // El título va primero: casi todos lo tienen y así no se toca la relación.
    var needsDetails: Bool {
        title.isEmpty && category == nil
    }

    static let needsDetailsSymbolName = "square.and.pencil"
}
