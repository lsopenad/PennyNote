import Foundation
import SwiftData

@Model
final class ExpenseCategory {
    var id: UUID
    var name: String
    // CategoryIcon.storedValue: el nombre del símbolo o el emoji. Hasta la 1.9.1 solo podía ser un
    // símbolo y se llamaba symbolName (ver PennyNoteMigrationPlan).
    @Attribute(originalName: "symbolName") private(set) var storedIcon: String
    var sortOrder: Int

    var icon: CategoryIcon {
        get { CategoryIcon(storedValue: storedIcon) }
        set { storedIcon = newValue.storedValue }
    }

    // Contabilidad de la sincronización, como en Expense.
    var localLastModified: Date
    var syncStatus: SyncStatus

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense] = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringExpense.category)
    var recurringExpenses: [RecurringExpense] = []

    init(
        id: UUID = UUID(),
        name: String,
        icon: CategoryIcon,
        sortOrder: Int
    ) {
        self.id = id
        self.name = name
        self.storedIcon = icon.storedValue
        self.sortOrder = sortOrder
        self.localLastModified = .now
        self.syncStatus = .pending
    }
}

extension ExpenseCategory {
    // Etiqueta que se muestra para los gastos sin categoría asignada.
    static var uncategorizedLabel: String { String(localized: "Sin categoría") }
    static let uncategorizedIcon = CategoryIcon.symbol("questionmark.circle")
    // Icono con el que empieza la ficha de una categoría nueva.
    static let defaultIcon = CategoryIcon.symbol("tag.fill")

    // Dos nombres son el mismo si solo cambian las mayúsculas, los acentos o los espacios: «Ocio» y
    // « ocio » no pueden ser dos categorías. La ñ no es una n con acento: «Año» y «Ano» son distintas.
    static func nameKey(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
            .replacingOccurrences(of: "ñ", with: enyePlaceholder)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    // Un carácter de uso privado, que no puede aparecer en un nombre, para que el plegado no toque la ñ.
    private static let enyePlaceholder = "\u{E000}"
}

// Cómo se muestra la categoría de un gasto, con «Sin categoría» cuando no tiene.
extension Optional where Wrapped == ExpenseCategory {
    var displayName: String {
        self?.name ?? ExpenseCategory.uncategorizedLabel
    }

    var displayIcon: CategoryIcon {
        self?.icon ?? ExpenseCategory.uncategorizedIcon
    }
}
