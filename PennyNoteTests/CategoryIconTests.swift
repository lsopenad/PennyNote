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

    @Test(arguments: ["fork.knife", "car.fill", "tag"])
    func symbolNamesAreSymbols(stored: String) {
        #expect(CategoryIcon(storedValue: stored) == .symbol(stored))
    }

    // Banderas, teclas y emojis compuestos también llevan caracteres que no son ASCII.
    @Test(arguments: ["🍕", "🇪🇸", "1️⃣", "👨‍👩‍👧", "❤️"])
    func emojisAreEmojis(stored: String) {
        let icon = CategoryIcon(storedValue: stored)

        #expect(icon == .emoji(stored))
        #expect(icon.storedValue == stored)
    }

    @Test func everyCatalogSymbolExists() {
        let missing = CategorySymbolCatalog.groups.flatMap(\.symbols).filter { UIImage(systemName: $0) == nil }

        #expect(missing.isEmpty)
    }

    @Test func catalogSymbolsAreNotRepeated() {
        let symbols = CategorySymbolCatalog.groups.flatMap(\.symbols)

        #expect(Set(symbols).count == symbols.count)
    }

    @Test func emojiCatalogHasEveryGroupWithoutSkinTones() throws {
        let catalog = EmojiCatalog(resource: "EmojiCatalog", language: "es")
        let emojis = catalog.groups.flatMap(\.emojis)
        let skinTones = Set((0x1F3FB...0x1F3FF).compactMap(Unicode.Scalar.init))

        #expect(catalog.groups.map(\.kind) == EmojiGroup.allCases)
        #expect(emojis.count > 1800)
        #expect(emojis.allSatisfy { $0.value.unicodeScalars.allSatisfy { !skinTones.contains($0) } })
        #expect(emojis.allSatisfy { CategoryIcon(storedValue: $0.value) == .emoji($0.value) })
        let pizza = try #require(emojis.first { $0.value == "🍕" })
        #expect(pizza.name == "pizza")
    }

    @Test func emojiSearchIgnoresCaseAndAccentsAndNeedsEveryWord() {
        let catalog = EmojiCatalog(resource: "EmojiCatalog", language: "es")

        #expect(catalog.search("PIZZA").map(\.value).contains("🍕"))
        #expect(catalog.search("cafe").map(\.value).contains("☕"))
        #expect(catalog.search("bandera españa").map(\.value) == ["🇪🇸"])
        #expect(catalog.search("   ").isEmpty)
    }

    @Test func emojiSearchUsesTheAppLanguage() {
        let catalog = EmojiCatalog(resource: "EmojiCatalog", language: "en")

        #expect(catalog.search("grapes").map(\.value).contains("🍇"))
        #expect(catalog.search("uvas").isEmpty)
    }

    @Test func missingCatalogIsEmpty() {
        #expect(EmojiCatalog(resource: "NoExiste", language: "es").groups.isEmpty)
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
        let category = ExpenseRepository.addCategory(name: "  Viajes ", icon: .emoji("✈️"), context: context)

        #expect(category.name == "Viajes")
        #expect(category.icon == .emoji("✈️"))
        #expect(category.syncStatus == .pending)
    }

    @Test func updateCategoryRenamesAndChangesTheIcon() {
        let category = insertSyncedCategory()
        let before = category.localLastModified

        ExpenseRepository.updateCategory(category, name: "Restaurantes ", icon: .emoji("🍕"), context: context)

        #expect(category.name == "Restaurantes")
        #expect(category.icon == .emoji("🍕"))
        #expect(category.syncStatus == .pending)
        #expect(category.localLastModified >= before)
    }

    // Guardar la ficha tal cual no vuelve a subir la categoría.
    @Test func updateCategoryWithoutChangesWritesNothing() {
        let category = insertSyncedCategory()

        ExpenseRepository.updateCategory(category, name: "Comida", icon: .symbol("fork.knife"), context: context)

        #expect(category.syncStatus == .synced)
    }

    @Test func remoteCategoryRoundTripsTheIcon() throws {
        let category = insertSyncedCategory()
        category.icon = .emoji("🍕")

        let remote = RemoteCategory(category)
        let decoded = try JSONDecoder().decode(RemoteCategory.self, from: JSONEncoder().encode(remote))

        #expect(decoded == remote)
        #expect(decoded.icon == "🍕")
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
        let category = ExpenseCategory(name: "Comida", icon: .symbol("fork.knife"), sortOrder: 0)
        category.syncStatus = .synced
        context.insert(category)
        return category
    }
}
