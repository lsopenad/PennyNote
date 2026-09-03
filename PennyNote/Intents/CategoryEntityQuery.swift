import AppIntents
import SwiftData
import Foundation
import os

struct CategoryEntityQuery: EntityQuery {
    func entities(for identifiers: [CategoryEntity.ID]) async throws -> [CategoryEntity] {
        let context = ModelContext(SharedModelContainer.container)
        let categories: [ExpenseCategory]
        do {
            categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        } catch {
            Log.data.error("Fallo al buscar categorías por id desde Atajos: \(error.localizedDescription)")
            categories = []
        }
        return categories
            .filter { identifiers.contains($0.id) }
            .map(CategoryEntity.init)
    }

    func suggestedEntities() async throws -> [CategoryEntity] {
        let context = ModelContext(SharedModelContainer.container)
        let descriptor = FetchDescriptor<ExpenseCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        let categories: [ExpenseCategory]
        do {
            categories = try context.fetch(descriptor)
        } catch {
            Log.data.error("Fallo al sugerir categorías desde Atajos: \(error.localizedDescription)")
            categories = []
        }
        return categories.map(CategoryEntity.init)
    }
}
