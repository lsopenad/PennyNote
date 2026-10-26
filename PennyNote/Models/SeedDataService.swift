import Foundation
import SwiftData
import os

enum SeedDataService {
    // Categoría a la que se reasignan los gastos al borrar la suya; se identifica por nombre
    // (isDefault no sirve: marca todas las categorías sembradas, no solo esta).
    static let fallbackCategoryName = "Otros"

    // Set clásico de 7 categorías que cubre la mayoría de gastos diarios sin abrumar el picker.
    static let defaultCategories: [(name: String, symbolName: String)] = [
        ("Comida", "fork.knife"),
        ("Transporte", "car.fill"),
        ("Ocio", "gamecontroller.fill"),
        ("Hogar", "house.fill"),
        ("Salud", "cross.case.fill"),
        ("Compras", "bag.fill"),
        (fallbackCategoryName, "ellipsis.circle.fill"),
    ]

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
                name: seed.name,
                symbolName: seed.symbolName,
                sortOrder: index,
                isDefault: true
            )
            context.insert(category)
        }
    }

    // nil si el usuario la ha borrado o renombrado; quien la usa elige entonces otra categoría.
    static func fallbackCategory(context: ModelContext) -> ExpenseCategory? {
        let name = fallbackCategoryName
        var descriptor = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        return context.fetchOrEmpty(descriptor, failureMessage: "Fallo al buscar la categoría de fallback").first
    }
}
