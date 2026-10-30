import Foundation
import SwiftData

enum SeedDataService {
    // Categoría a la que se reasignan los gastos al borrar la suya; se identifica por nombre, en
    // cualquiera de los idiomas de la app, porque se crea en el del móvil que abrió la cuenta.
    private static let fallbackCategory: LocalizedStringResource = "Otros"
    private static let fallbackCategoryNames: [String] = ["Otros", "Other", "其他"]

    // Set clásico de 7 categorías que cubre la mayoría de gastos diarios sin abrumar el picker. Se
    // crean en el idioma del móvil; después son datos del usuario y no se traducen.
    static let defaultCategories: [(name: LocalizedStringResource, symbolName: String)] = [
        ("Comida", "fork.knife"),
        ("Transporte", "car.fill"),
        ("Ocio", "gamecontroller.fill"),
        ("Hogar", "house.fill"),
        ("Salud", "cross.case.fill"),
        ("Compras", "bag.fill"),
        (fallbackCategory, "ellipsis.circle.fill"),
    ]

    // Lo llama SyncEngine tras bajar los datos de la cuenta: sin categorías es una cuenta nueva.
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<ExpenseCategory>()
        let existingCount: Int
        do {
            existingCount = try context.fetchCount(descriptor)
        } catch {
            Log.data.error("Fallo al comprobar categorías existentes antes de sembrar: \(error.localizedDescription)")
            existingCount = 0
        }
        guard existingCount == 0 else { return }

        for (index, seed) in defaultCategories.enumerated() {
            let category = ExpenseCategory(
                name: String(localized: seed.name),
                symbolName: seed.symbolName,
                sortOrder: index,
                color: CategoryColor.allCases[index % CategoryColor.allCases.count]
            )
            context.insert(category)
        }
    }

    // nil si el usuario la ha borrado o renombrado; quien la usa elige entonces otra categoría.
    static func fallbackCategory(context: ModelContext) -> ExpenseCategory? {
        let names = fallbackCategoryNames
        var descriptor = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { names.contains($0.name) })
        descriptor.fetchLimit = 1
        return context.fetchOrEmpty(descriptor, failureMessage: "Fallo al buscar la categoría de fallback").first
    }
}
