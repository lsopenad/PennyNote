import Foundation
import SwiftData

@Model
final class ExpenseCategory {
    var id: UUID
    var name: String
    var symbolName: String
    var sortOrder: Int
    // Marca las categorías creadas por el seed; ahora mismo no se lee.
    var isDefault: Bool
    // Reservado para mapear la opción "select" de Notion por ID; hoy nunca se rellena y el pull
    // empareja las categorías por nombre. Se conserva para no alterar el esquema.
    var notionSelectOptionID: String?

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense] = []

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        sortOrder: Int,
        isDefault: Bool = false,
        notionSelectOptionID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.notionSelectOptionID = notionSelectOptionID
    }
}
