import SwiftUI
import SwiftData

@Model
final class ExpenseCategory {
    var id: UUID
    var name: String
    var symbolName: String
    var sortOrder: Int

    // Se guarda el rawValue y no el enum para que un valor desconocido no impida leer la categoría.
    // nil es una categoría sin color (la columna color_name del servidor admite NULL).
    private var storedColorName: String?

    var color: CategoryColor? {
        get { storedColorName.flatMap(CategoryColor.init(rawValue:)) }
        set { storedColorName = newValue?.rawValue }
    }

    // Contabilidad de la sincronización, como en Expense.
    var localLastModified: Date
    var syncStatus: SyncStatus

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense] = []

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        sortOrder: Int,
        color: CategoryColor? = nil
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.storedColorName = color?.rawValue
        self.localLastModified = .now
        self.syncStatus = .pending
    }
}

extension ExpenseCategory {
    // Etiqueta que se muestra para los gastos sin categoría asignada.
    static let uncategorizedLabel = "Sin categoría"
    static let uncategorizedSymbolName = "questionmark.circle"
    // Icono de las categorías que crea el usuario desde Ajustes.
    static let defaultSymbolName = "tag.fill"

    // Color con el que se pinta la categoría; las que no tienen uno salen en gris.
    var displayColor: Color {
        color?.color ?? CategoryColor.neutral
    }
}

// Cómo se muestra la categoría de un gasto, con «Sin categoría» cuando no tiene.
extension Optional where Wrapped == ExpenseCategory {
    var displayName: String {
        self?.name ?? ExpenseCategory.uncategorizedLabel
    }

    var displaySymbolName: String {
        self?.symbolName ?? ExpenseCategory.uncategorizedSymbolName
    }

    var displayColor: Color {
        self?.displayColor ?? CategoryColor.neutral
    }
}
