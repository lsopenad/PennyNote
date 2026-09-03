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
    // Se actualiza en cada mutación local; es la base de la comparación last-write-wins.
    var localLastModified: Date

    // Todo lo relacionado con Notion queda a nil hasta que exista sync (fase 2).
    var notionPageID: String?
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
        self.paymentMethod = paymentMethod
        self.category = category
        self.createdAt = .now
        self.localLastModified = .now
        self.notionPageID = nil
        self.notionLastEditedTime = nil
        self.syncStatus = .pending
        self.isDeleted = false
    }
}
