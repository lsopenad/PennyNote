import Foundation
import SwiftData

@Model
final class ExpenseCategory {
    var id: UUID
    var name: String
    var symbolName: String
    var sortOrder: Int
    var isDefault: Bool
    // ID de la opción "select" en Notion, para mantener el mapeo estable si se renombra la categoría.
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
