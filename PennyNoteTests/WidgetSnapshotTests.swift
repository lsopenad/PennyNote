import Foundation
import Testing
@testable import PennyNote

struct WidgetSnapshotTests {
    @Test func comparisonUsesTheSameDayOfThePreviousMonth() throws {
        let current = try month(2026, 3, totals: [10, 10, 10])
        let previous = try month(2026, 2, totals: [20, 5, 100])

        let change = try #require(SpendingComparison.change(current: current, previous: previous, throughDay: 2))

        #expect(abs(change - (-0.2)) < 0.0001)
    }

    @Test func comparisonCountsTheWholePreviousMonthWhenItIsShorter() throws {
        let current = try month(2026, 3, totals: Array(repeating: 1, count: 31))
        let previous = try month(2026, 2, totals: Array(repeating: 1, count: 28))

        let change = try #require(SpendingComparison.change(current: current, previous: previous, throughDay: 31))

        #expect(abs(change - (31.0 / 28.0 - 1)) < 0.0001)
    }

    @Test func comparisonIsNilWithoutPreviousSpending() throws {
        let current = try month(2026, 3, totals: [10])
        let previous = try month(2026, 2, totals: [0, 50])

        #expect(SpendingComparison.change(current: current, previous: previous, throughDay: 1) == nil)
    }

    @Test func snapshotRoundTripKeepsDecimalPrecision() throws {
        let snapshot = WidgetSnapshot(
            current: try month(2026, 3, totals: [Decimal(string: "0.1")!, Decimal(string: "1234.56")!]),
            previous: try month(2026, 2, totals: [Decimal(string: "0.3")!]),
            topCategories: [.init(name: "Comida", icon: .init(symbolName: "fork.knife"), color: nil, total: Decimal(string: "0.1")!)]
        )

        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(snapshot))

        #expect(decoded == snapshot)
    }

    @Test func displayKeepsTheSnapshotWithinTheSameMonth() throws {
        let snapshot = try makeSnapshot()

        let display = WidgetDisplay(snapshot: snapshot, at: try date(2026, 3, 20))

        #expect(display.current == snapshot.current)
        #expect(display.previous == snapshot.previous)
        #expect(display.topCategories == snapshot.topCategories)
        #expect(display.day == 20)
    }

    @Test func displayStartsTheNextMonthAtZero() throws {
        let snapshot = try makeSnapshot()

        let display = WidgetDisplay(snapshot: snapshot, at: try date(2026, 4, 1))

        #expect(display.current.monthStart == (try date(2026, 4, 1)))
        #expect(display.current.dailyTotals.count == 30)
        #expect(display.current.total == .zero)
        #expect(display.previous == snapshot.current)
        #expect(display.topCategories.isEmpty)
    }

    @Test func displayForgetsTheSnapshotAfterMoreThanAMonth() throws {
        let display = WidgetDisplay(snapshot: try makeSnapshot(), at: try date(2026, 5, 3))

        #expect(display.current.total == .zero)
        #expect(display.previous == nil)
    }

    // La 1.9.1 guardaba el icono como symbolName y con color: el widget lo lee hasta que la app se abre.
    @Test func snapshotFromTheOldVersionStillDecodes() throws {
        let json = """
        {"name":"Comida","symbolName":"fork.knife","colorName":"blue","total":"62"}
        """

        let category = try JSONDecoder().decode(WidgetSnapshot.CategoryTotal.self, from: Data(json.utf8))

        #expect(category == .init(name: "Comida", icon: .init(symbolName: "fork.knife"), color: nil, total: 62))
    }

    // Un snapshot de la 1.10.0 puede traer un emoji hasta que la app se abre.
    @Test func snapshotEmojiIconReadsAsTheFallback() throws {
        let json = """
        {"name":"Pizza","icon":"🍕","total":"12"}
        """

        let category = try JSONDecoder().decode(WidgetSnapshot.CategoryTotal.self, from: Data(json.utf8))

        #expect(category.icon == .fallback)
    }

    @Test func uncategorizedIconSurvivesTheRoundTrip() throws {
        let category = WidgetSnapshot.CategoryTotal(name: "Sin categoría", icon: .uncategorized, color: nil, total: 5)

        let decoded = try JSONDecoder().decode(WidgetSnapshot.CategoryTotal.self, from: JSONEncoder().encode(category))

        #expect(decoded.icon == .uncategorized)
    }

    @Test func categoryColorSurvivesTheRoundTrip() throws {
        let category = WidgetSnapshot.CategoryTotal(name: "Ocio", icon: .fallback, color: .custom(rgb: 0x12AB9F), total: 5)

        let decoded = try JSONDecoder().decode(WidgetSnapshot.CategoryTotal.self, from: JSONEncoder().encode(category))

        #expect(decoded.color == .custom(rgb: 0x12AB9F))
    }

    // Lo que escribía la 1.11.0, sin color.
    @Test func snapshotWithoutColorReadsAsNoColor() throws {
        let json = """
        {"name":"Comida","icon":"fork.knife","total":"12"}
        """

        let category = try JSONDecoder().decode(WidgetSnapshot.CategoryTotal.self, from: Data(json.utf8))

        #expect(category.color == nil)
    }

    private func makeSnapshot() throws -> WidgetSnapshot {
        WidgetSnapshot(
            current: try month(2026, 3, totals: Array(repeating: 2, count: 31)),
            previous: try month(2026, 2, totals: Array(repeating: 1, count: 28)),
            topCategories: [.init(name: "Comida", icon: .init(symbolName: "fork.knife"), color: .palette(.orange), total: 62)]
        )
    }

    private func month(_ year: Int, _ month: Int, totals: [Decimal]) throws -> MonthSpending {
        MonthSpending(monthStart: try date(year, month, 1), dailyTotals: totals)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(DateComponents(calendar: .current, year: year, month: month, day: day).date)
    }
}
