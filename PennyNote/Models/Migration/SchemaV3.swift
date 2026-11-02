import Foundation
import SwiftData

// Esquema de las versiones 1.6.0 a 1.9.1, copiado tal cual: SwiftData lo necesita para reconocer los
// almacenes que crearon esas versiones y migrarlos. No hay que tocarlo.
enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Expense.self, ExpenseCategory.self, RecurringExpense.self]
    }

    @Model
    final class Expense {
        var id: UUID
        var amount: Decimal
        var date: Date
        var title: String
        private(set) var storedPaymentMethod: String = PaymentMethod.card.rawValue
        var category: ExpenseCategory?
        var recurringExpenseID: UUID?
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

        @Relationship(deleteRule: .nullify, inverse: \RecurringExpense.category)
        var recurringExpenses: [RecurringExpense] = []

        init(id: UUID = UUID(), name: String, symbolName: String, sortOrder: Int, colorName: String? = nil) {
            self.id = id
            self.name = name
            self.symbolName = symbolName
            self.sortOrder = sortOrder
            self.storedColorName = colorName
            self.localLastModified = .now
            self.syncStatus = .pending
        }
    }

    @Model
    final class RecurringExpense {
        var id: UUID
        var amount: Decimal
        var title: String
        private(set) var storedPaymentMethod: String
        private(set) var storedFrequency: String
        var category: ExpenseCategory?
        var startDate: Date
        var nextDate: Date
        var isPaused: Bool
        var createdAt: Date
        var localLastModified: Date
        var syncStatus: SyncStatus
        var isSoftDeleted: Bool

        init(id: UUID = UUID(), amount: Decimal, frequency: RecurrenceFrequency, startDate: Date) {
            self.id = id
            self.amount = amount
            self.title = ""
            self.storedPaymentMethod = PaymentMethod.card.rawValue
            self.storedFrequency = frequency.rawValue
            self.startDate = startDate
            self.nextDate = startDate
            self.isPaused = false
            self.createdAt = .now
            self.localLastModified = .now
            self.syncStatus = .pending
            self.isSoftDeleted = false
        }
    }
}
