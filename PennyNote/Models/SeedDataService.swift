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
                isDefault: true,
                color: CategoryColor.allCases[index % CategoryColor.allCases.count]
            )
            context.insert(category)
        }
    }

    // Da color a las categorías creadas antes de que existiera el campo, sin repetir los ya usados.
    static func assignMissingColors(context: ModelContext) {
        let categories = context.fetchOrEmpty(
            FetchDescriptor<ExpenseCategory>(sortBy: [SortDescriptor(\.sortOrder)]),
            failureMessage: "Fallo al leer categorías para asignarles color"
        )
        var usedColors = categories.compactMap(\.color)
        let uncolored = categories.filter { $0.color == nil }
        guard !uncolored.isEmpty else { return }

        for category in uncolored {
            let color = CategoryColor.nextAvailable(excluding: usedColors)
            category.color = color
            usedColors.append(color)
        }
        context.saveOrLog(failureMessage: "Fallo al guardar los colores asignados a las categorías")
    }

    // nil si el usuario la ha borrado o renombrado; quien la usa elige entonces otra categoría.
    static func fallbackCategory(context: ModelContext) -> ExpenseCategory? {
        let name = fallbackCategoryName
        var descriptor = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        return context.fetchOrEmpty(descriptor, failureMessage: "Fallo al buscar la categoría de fallback").first
    }
}
