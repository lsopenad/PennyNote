import AppIntents
import SwiftData
import Foundation

struct CategoryEntityQuery: EntityQuery {
    func entities(for identifiers: [CategoryEntity.ID]) async throws -> [CategoryEntity] {
        let context = ModelContext(SharedModelContainer.container)
        let categories = (try? context.fetch(FetchDescriptor<ExpenseCategory>())) ?? []
        return categories
            .filter { identifiers.contains($0.id) }
            .map(CategoryEntity.init)
    }

    func suggestedEntities() async throws -> [CategoryEntity] {
        let context = ModelContext(SharedModelContainer.container)
        let descriptor = FetchDescriptor<ExpenseCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        let categories = (try? context.fetch(descriptor)) ?? []
        return categories.map(CategoryEntity.init)
    }
}
