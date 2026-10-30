import Foundation
import SwiftData

// Esquema de las versiones 1.3.0 a 1.5.0, copiado tal cual: SwiftData lo necesita para reconocer los
// almacenes que crearon esas versiones y migrarlos. No hay que tocarlo.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Expense.self, ExpenseCategory.self]
    }

    @Model
    final class Expense {
        var id: UUID
        var amount: Decimal
        var date: Date
        var title: String
        // La migración desde V1 lo rellena en didMigrate.
        var storedPaymentMethod: String = PaymentMethod.card.rawValue
        var category: ExpenseCategory?
        var createdAt: Date
        var localLastModified: Date
        var syncStatus: SyncStatus
        var isSoftDeleted: Bool

        init(id: UUID = UUID(), amount: Decimal, paymentMethod: PaymentMethod) {
            self.id = id
            self.amount = amount
            self.date = .now
            self.title = ""
            self.storedPaymentMethod = paymentMethod.rawValue
            self.createdAt = .now
            self.localLastModified = .now
            self.syncStatus = .pending
            self.isSoftDeleted = false
        }
    }

    @Model
    final class ExpenseCategory {
        var id: UUID
        var name: String
        var symbolName: String
        var sortOrder: Int
        private var storedColorName: String?
        var localLastModified: Date
        var syncStatus: SyncStatus

        @Relationship(deleteRule: .nullify, inverse: \Expense.category)
        var expenses: [Expense] = []

        init(id: UUID = UUID(), name: String, symbolName: String, sortOrder: Int) {
            self.id = id
            self.name = name
            self.symbolName = symbolName
            self.sortOrder = sortOrder
            self.storedColorName = nil
            self.localLastModified = .now
            self.syncStatus = .pending
        }
    }
}
