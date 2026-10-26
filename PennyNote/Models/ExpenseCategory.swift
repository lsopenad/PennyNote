import SwiftUI
import SwiftData

@Model
final class ExpenseCategory {
    var id: UUID
    var name: String
    var symbolName: String
    var sortOrder: Int
    // Marca las categorías creadas por el seed; ahora mismo no se lee.
    var isDefault: Bool

    // Opcional en disco: las categorías anteriores a este campo quedan a NULL al migrar hasta que
    // SeedDataService.assignMissingColors les da uno. Se guarda el rawValue y no el enum para que un
    // valor desconocido no impida leer la categoría.
    private var storedColorName: String?

    var color: CategoryColor? {
        get { storedColorName.flatMap(CategoryColor.init(rawValue:)) }
        set { storedColorName = newValue?.rawValue }
    }

    // Contabilidad de la sincronización, como en Expense. Con valor por defecto o opcional para la
    // migración ligera; una categoría anterior a estos campos cuenta como pendiente de subir.
    var localLastModified: Date = Date.distantPast
    private var storedSyncStatus: SyncStatus?

    var syncStatus: SyncStatus {
        get { storedSyncStatus ?? .pending }
        set { storedSyncStatus = newValue }
    }

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense] = []

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        sortOrder: Int,
        isDefault: Bool = false,
        color: CategoryColor? = nil
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.storedColorName = color?.rawValue
        self.localLastModified = .now
        self.storedSyncStatus = .pending
    }
}

extension ExpenseCategory {
    // Etiqueta que se muestra para los gastos sin categoría asignada.
    static let uncategorizedLabel = "Sin categoría"
    static let uncategorizedSymbolName = "questionmark.circle"
    // Icono de las categorías que crea el usuario desde Ajustes.
    static let defaultSymbolName = "tag.fill"

    // Color con el que se pinta la categoría; las que aún no tienen uno salen en gris.
    var displayColor: Color {
        color?.color ?? CategoryColor.neutral
    }
}
