import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import PennyNote

@MainActor
struct CategoryColorTests {
    private let context: ModelContext

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, RecurringExpense.self, configurations: configuration)
        context = ModelContext(container)
    }

    @Test(arguments: CategoryPaletteColor.allCases)
    func paletteColorsRoundTripByName(paletteColor: CategoryPaletteColor) {
        let color = CategoryColor.palette(paletteColor)

        #expect(color.storedValue == paletteColor.rawValue)
        #expect(CategoryColor(storedValue: color.storedValue) == color)
    }

    @Test func customColorIsStoredAsUppercaseHex() {
        #expect(CategoryColor.custom(rgb: 0x0a1b2c).storedValue == "#0A1B2C")
        #expect(CategoryColor(storedValue: "#0a1b2c") == .custom(rgb: 0x0A1B2C))
        #expect(CategoryColor(storedValue: "#FFFFFF") == .custom(rgb: 0xFFFFFF))
    }

    // Sin color, de una versión futura o basura: se muestra sin color.
    @Test(arguments: [nil, "", "magenta", "#12345", "#1234567", "#-12345", "#+12345", "#GGGGGG", "123456"])
    func unknownStoredValuesReadAsNoColor(stored: String?) {
        #expect(CategoryColor(storedValue: stored) == nil)
    }

    @Test func resolvedColorBecomesCustomHex() {
        let resolved = Color.Resolved(colorSpace: .sRGB, red: 1, green: 0.5, blue: 0)

        #expect(CategoryColor(resolved: resolved) == .custom(rgb: 0xFF8000))
    }

    // Los componentes fuera de sRGB (Display P3) se recortan.
    @Test func resolvedColorOutsideSRGBIsClamped() {
        let resolved = Color.Resolved(colorSpace: .sRGB, red: 1.2, green: -0.1, blue: 0.5)

        #expect(CategoryColor(resolved: resolved) == .custom(rgb: 0xFF0080))
    }

    @Test func symbolIsBlackOnLightColorsAndWhiteOnDarkOnes() {
        let environment = EnvironmentValues()

        #expect(CategoryColor.palette(.yellow).symbolColor(in: environment) == .black)
        #expect(CategoryColor.custom(rgb: 0xFFFFFF).symbolColor(in: environment) == .black)
        #expect(CategoryColor.palette(.blue).symbolColor(in: environment) == .white)
        #expect(CategoryColor.palette(.green).symbolColor(in: environment) == .white)
        #expect(CategoryColor.custom(rgb: 0x000000).symbolColor(in: environment) == .white)
    }

    @Test func addCategoryKeepsTheColor() {
        let category = ExpenseRepository.addCategory(name: "Viajes", icon: .fallback, color: .custom(rgb: 0x336699), context: context)

        #expect(category.color == .custom(rgb: 0x336699))
    }

    @Test func changingOnlyTheColorMarksTheCategoryPending() {
        let category = insertSyncedCategory(color: .palette(.red))

        ExpenseRepository.updateCategory(category, name: category.name, icon: category.icon, color: .palette(.blue), context: context)

        #expect(category.color == .palette(.blue))
        #expect(category.syncStatus == .pending)
    }

    @Test func removingTheColorMarksTheCategoryPending() {
        let category = insertSyncedCategory(color: .palette(.red))

        ExpenseRepository.updateCategory(category, name: category.name, icon: category.icon, color: nil, context: context)

        #expect(category.color == nil)
        #expect(category.syncStatus == .pending)
    }

    @Test func remoteCategoryRoundTripsTheColor() throws {
        let category = insertSyncedCategory(color: .custom(rgb: 0x12AB9F))

        let remote = RemoteCategory(category)
        let decoded = try JSONDecoder().decode(RemoteCategory.self, from: JSONEncoder().encode(remote))

        #expect(remote.color == "#12AB9F")
        #expect(decoded == remote)
    }

    // Quitar el color tiene que llegar al servidor como null: si se omitiera, el upsert lo conservaría.
    @Test func remoteCategoryWithoutColorSendsNull() throws {
        let category = insertSyncedCategory(color: nil)

        let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(RemoteCategory(category))) as? [String: Any])

        #expect(json.keys.contains("color"))
        #expect(json["color"] is NSNull)
    }

    // Borrados pendientes guardados por la 1.11.0, sin color.
    @Test func remoteCategoryWithoutColorKeyDecodes() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"Ocio","icon":"tag.fill","sort_order":0,"is_deleted":true,"updated_at":0}
        """

        let decoded = try JSONDecoder().decode(RemoteCategory.self, from: Data(json.utf8))

        #expect(decoded.color == nil)
    }

    private func insertSyncedCategory(color: CategoryColor?) -> ExpenseCategory {
        let category = ExpenseCategory(name: "Comida", icon: .init(symbolName: "fork.knife"), color: color, sortOrder: 0)
        category.syncStatus = .synced
        context.insert(category)
        try? context.save()
        return category
    }
}
