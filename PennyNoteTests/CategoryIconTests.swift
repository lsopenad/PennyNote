import Foundation
import SwiftData
import Testing
import UIKit
@testable import PennyNote

@MainActor
struct CategoryIconTests {
    private let context: ModelContext

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, RecurringExpense.self, configurations: configuration)
        context = ModelContext(container)
    }

    @Test(arguments: ["fork.knife", "car.fill", "ellipsis.circle.fill"])
    func catalogSymbolsAreKept(stored: String) {
        #expect(CategoryIcon(storedValue: stored).symbolName == stored)
    }

    // Emojis de la 1.10.0 (también compuestos y banderas), símbolos retirados del catálogo y basura.
    @Test(arguments: ["🍕", "🇪🇸", "👨‍👩‍👧", "tram", "questionmark.circle", ""])
    func storedValuesOutsideTheCatalogBecomeTheFallback(stored: String) {
        #expect(CategoryIcon(storedValue: stored) == .fallback)
    }

    @Test func catalogHasSeventyDistinctSymbolsThatExist() {
        let names = CategorySymbolCatalog.symbols.map(\.name)

        #expect(names.count == 70)
        #expect(Set(names).count == names.count)
        #expect(names.filter { UIImage(systemName: $0) == nil }.isEmpty)
    }

    // Si no, las de serie y las nuevas se cambiarían por otro icono nada más crearse.
    @Test func defaultIconsAreInTheCatalog() {
        let icons = SeedDataService.defaultCategories.map(\.icon) + [CategoryIcon.fallback]

        #expect(icons.allSatisfy { CategorySymbolCatalog.contains($0.symbolName) })
        #expect(!CategorySymbolCatalog.contains(ExpenseCategory.uncategorizedIcon.symbolName))
    }

    @Test func categoryWithAStoredEmojiShowsTheFallback() {
        let category = ExpenseCategory(name: "Pizza", icon: CategoryIcon(symbolName: "🍕"), sortOrder: 0)

        #expect(category.icon == .fallback)
        #expect(category.hasUnknownStoredIcon)
        #expect(RemoteCategory(category).icon == "tag.fill")
    }

    @Test func namesDifferingInCaseAccentsOrSpacesAreTheSame() {
        #expect(ExpenseCategory.nameKey("Ocio") == ExpenseCategory.nameKey("  ocio "))
        #expect(ExpenseCategory.nameKey("Café") == ExpenseCategory.nameKey("CAFE"))
        #expect(ExpenseCategory.nameKey("Super  mercado") == ExpenseCategory.nameKey("super mercado"))
        #expect(ExpenseCategory.nameKey("Ocio") != ExpenseCategory.nameKey("Hogar"))
        #expect(ExpenseCategory.nameKey("Año") != ExpenseCategory.nameKey("Ano"))
        #expect(ExpenseCategory.nameKey("AÑO") == ExpenseCategory.nameKey("año"))
    }

    @Test func addCategoryTrimsTheName() {
        let category = ExpenseRepository.addCategory(name: "  Viajes ", icon: .init(symbolName: "airplane"), color: nil, context: context)

        #expect(category.name == "Viajes")
        #expect(category.icon == .init(symbolName: "airplane"))
        #expect(category.syncStatus == .pending)
    }

    @Test func updateCategoryRenamesAndChangesTheIcon() {
        let category = insertSyncedCategory()
        let before = category.localLastModified

        ExpenseRepository.updateCategory(category, name: "Restaurantes ", icon: .init(symbolName: "takeoutbag.and.cup.and.straw.fill"), color: nil, context: context)

        #expect(category.name == "Restaurantes")
        #expect(category.icon == .init(symbolName: "takeoutbag.and.cup.and.straw.fill"))
        #expect(category.syncStatus == .pending)
        #expect(category.localLastModified >= before)
    }

    // Guardar la ficha tal cual no vuelve a subir la categoría.
    @Test func updateCategoryWithoutChangesWritesNothing() {
        let category = insertSyncedCategory()

        ExpenseRepository.updateCategory(category, name: "Comida", icon: .init(symbolName: "fork.knife"), color: nil, context: context)

        #expect(category.syncStatus == .synced)
    }

    @Test func remoteCategoryRoundTripsTheIcon() throws {
        let category = insertSyncedCategory()
        category.icon = .init(symbolName: "birthday.cake.fill")

        let remote = RemoteCategory(category)
        let decoded = try JSONDecoder().decode(RemoteCategory.self, from: JSONEncoder().encode(remote))

        #expect(decoded == remote)
        #expect(decoded.icon == "birthday.cake.fill")
    }

    // Los borrados de categorías pendientes de subir se guardaron con la 1.9.1, con symbol_name y color.
    @Test func categoryTombstoneFromTheOldVersionStillDecodes() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","name":"Ocio","symbol_name":"gamecontroller.fill","sort_order":2,\
        "color_name":"green","is_deleted":true,"updated_at":0}
        """

        let tombstone = try JSONDecoder().decode(RemoteCategory.self, from: Data(json.utf8))

        #expect(tombstone.id == id)
        #expect(tombstone.icon == "gamecontroller.fill")
        #expect(tombstone.isDeleted)
    }

    private func insertSyncedCategory() -> ExpenseCategory {
        let category = ExpenseCategory(name: "Comida", icon: .init(symbolName: "fork.knife"), sortOrder: 0)
        category.syncStatus = .synced
        context.insert(category)
        return category
    }
}
