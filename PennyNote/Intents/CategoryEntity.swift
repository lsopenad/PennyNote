import AppIntents
import Foundation

// Respaldada por ExpenseCategory real (no un AppEnum fijo) porque las categorías son editables.
struct CategoryEntity: AppEntity {
    let id: UUID
    let name: String
    let icon: CategoryIcon

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Categoría"
    static var defaultQuery = CategoryEntityQuery()

    // La imagen de Atajos solo admite símbolos: el emoji va delante del nombre.
    var displayRepresentation: DisplayRepresentation {
        switch icon {
        case .symbol(let symbolName):
            DisplayRepresentation(title: "\(name)", image: .init(systemName: symbolName))
        case .emoji(let emoji):
            DisplayRepresentation(title: "\(emoji) \(name)")
        }
    }
}

extension CategoryEntity {
    init(_ category: ExpenseCategory) {
        self.id = category.id
        self.name = category.name
        self.icon = category.icon
    }
}
