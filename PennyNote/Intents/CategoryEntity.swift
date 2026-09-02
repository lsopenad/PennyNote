import AppIntents
import Foundation

// Respaldada por ExpenseCategory real (no un AppEnum fijo) porque las categorías son editables.
struct CategoryEntity: AppEntity, Identifiable {
    let id: UUID
    let name: String
    let symbolName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Categoría"
    static var defaultQuery = CategoryEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbolName))
    }
}

extension CategoryEntity {
    init(_ category: ExpenseCategory) {
        self.id = category.id
        self.name = category.name
        self.symbolName = category.symbolName
    }
}
