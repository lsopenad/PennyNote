import AppIntents
import Foundation

// Respaldada por ExpenseCategory real (no un AppEnum fijo) porque las categorías son editables.
struct CategoryEntity: AppEntity {
    let id: UUID
    let name: String
    let icon: CategoryIcon

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Categoría"
    static var defaultQuery = CategoryEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: icon.symbolName))
    }
}

extension CategoryEntity {
    init(_ category: ExpenseCategory) {
        self.id = category.id
        self.name = category.name
        self.icon = category.icon
    }
}
