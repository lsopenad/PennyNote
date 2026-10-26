import AppIntents
import SwiftData
import Foundation

struct CategoryEntityQuery: EntityQuery {
    func entities(for identifiers: [CategoryEntity.ID]) async throws -> [CategoryEntity] {
        let context = ModelContext(SharedModelContainer.container)
        let descriptor = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { identifiers.contains($0.id) })
        return context
            .fetchOrEmpty(descriptor, failureMessage: "Fallo al buscar categorías por id desde Atajos")
            .map(CategoryEntity.init)
    }

    func suggestedEntities() async throws -> [CategoryEntity] {
        let context = ModelContext(SharedModelContainer.container)
        let descriptor = FetchDescriptor<ExpenseCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        return context
            .fetchOrEmpty(descriptor, failureMessage: "Fallo al sugerir categorías desde Atajos")
            .map(CategoryEntity.init)
    }
}
