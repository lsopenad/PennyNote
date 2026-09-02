import Foundation
import SwiftData

enum SeedDataService {
    // Set clásico de 7 categorías que cubre la mayoría de gastos diarios sin abrumar el picker.
    static let defaultCategories: [(name: String, symbolName: String)] = [
        ("Comida", "fork.knife"),
        ("Transporte", "car.fill"),
        ("Ocio", "gamecontroller.fill"),
        ("Hogar", "house.fill"),
        ("Salud", "cross.case.fill"),
        ("Compras", "bag.fill"),
        ("Otros", "ellipsis.circle.fill"),
    ]

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<ExpenseCategory>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
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

    // La categoría "Otros" siempre debe existir como fallback de reasignación al borrar categorías.
    static func fallbackCategory(context: ModelContext) -> ExpenseCategory? {
        var descriptor = FetchDescriptor<ExpenseCategory>(
            predicate: #Predicate { $0.name == "Otros" }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
