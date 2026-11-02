import Foundation
import SwiftData
import Testing
@testable import PennyNote

@MainActor
struct ExpenseSuggestionIndexTests {
    private let context: ModelContext
    private let now: Date

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, RecurringExpense.self, configurations: configuration)
        context = ModelContext(container)
        now = try #require(DateComponents(calendar: .current, year: 2026, month: 11, day: 2, hour: 12).date)
    }

    @Test func suggestionsMatchTheStartOfAnyWordIgnoringCaseAndAccents() {
        let index = makeIndex([
            insertExpense("Mercadona Gran Vía"),
            insertExpense("Café"),
            insertExpense("Cine"),
        ])

        #expect(index.suggestions(matching: "gran").map(\.title) == ["Mercadona Gran Vía"])
        #expect(index.suggestions(matching: "VIA").map(\.title) == ["Mercadona Gran Vía"])
        #expect(index.suggestions(matching: " cafe ").map(\.title) == ["Café"])
        // No basta con que aparezca en medio de una palabra.
        #expect(index.suggestions(matching: "dona").isEmpty)
    }

    @Test func suggestionsNeedAtLeastTwoLetters() {
        let index = makeIndex([insertExpense("Mercadona")])

        #expect(index.suggestions(matching: "m").isEmpty)
        #expect(index.suggestions(matching: "me").count == 1)
    }

    // Los gastos con el mismo título dan una sola sugerencia, con los datos del más reciente.
    @Test func expensesWithTheSameTitleGiveOneSuggestionFromTheMostRecent() {
        let food = insertCategory("Comida")
        let index = makeIndex([
            insertExpense("cafe ", amount: 1.5, daysAgo: 30, paymentMethod: .card),
            insertExpense("Café", amount: 2.5, daysAgo: 2, category: food, paymentMethod: .cash),
        ])

        let suggestions = index.suggestions(matching: "caf")

        #expect(suggestions.count == 1)
        #expect(suggestions.first?.title == "Café")
        #expect(suggestions.first?.amount == 2.5)
        #expect(suggestions.first?.category === food)
        #expect(suggestions.first?.paymentMethod == .cash)
    }

    @Test func suggestionsAreOrderedByFrequencyAndRecencyUpToThree() {
        let index = makeIndex([
            insertExpense("Mercadona", daysAgo: 10),
            insertExpense("Mercadona", daysAgo: 20),
            insertExpense("Mercadona", daysAgo: 30),
            insertExpense("Mercadona", daysAgo: 40),
            insertExpense("Mercería", daysAgo: 1),
            insertExpense("Mercado", daysAgo: 200),
            insertExpense("Merienda", daysAgo: 300),
        ])

        #expect(index.suggestions(matching: "mer").map(\.title) == ["Mercadona", "Mercería", "Mercado"])
    }

    @Test func deletedAndOlderThanTwelveMonthsExpensesAreIgnored() {
        let deleted = insertExpense("Gimnasio")
        deleted.isSoftDeleted = true
        let index = makeIndex([deleted, insertExpense("Gafas", daysAgo: 400)])

        #expect(index.suggestions(matching: "gi").isEmpty)
        #expect(index.suggestions(matching: "ga").isEmpty)
        #expect(index.prediction(for: "Gafas").category == nil)
    }

    @Test func loadReadsOnlyRecentExpensesWithTitle() throws {
        insertExpense("Mercadona", daysAgo: 5)
        insertExpense("Mercado", daysAgo: 400)
        insertExpense("", daysAgo: 1)
        try context.save()

        let index = ExpenseSuggestionIndex.load(context: context, now: now)

        #expect(index.suggestions(matching: "mer").map(\.title) == ["Mercadona"])
    }

    // Un título que ya existe usa los datos de su gasto más reciente.
    @Test func predictionForAKnownTitleUsesItsMostRecentExpense() {
        let food = insertCategory("Comida")
        let leisure = insertCategory("Ocio")
        let index = makeIndex([
            insertExpense("Café", daysAgo: 30, category: leisure, paymentMethod: .card),
            insertExpense("Café", daysAgo: 1, category: food, paymentMethod: .cash),
        ])

        let prediction = index.prediction(for: "café")

        #expect(prediction.category === food)
        #expect(prediction.paymentMethod == .cash)
    }

    // Si ese título se guarda sin categoría, no se toma la que deducen sus palabras.
    @Test func predictionForAKnownTitleWithoutCategoryIgnoresTheWords() {
        let groceries = insertCategory("Supermercado")
        let index = makeIndex([
            insertExpense("Mercadona Centro", category: groceries),
            insertExpense("Mercadona Sur", category: groceries),
            insertExpense("Mercadona Regalo"),
        ])

        #expect(index.prediction(for: "Mercadona Regalo").category == nil)
    }

    @Test func predictionFromTheWordsOfANewTitle() {
        let groceries = insertCategory("Supermercado")
        let index = makeIndex([
            insertExpense("Mercadona Centro", category: groceries, paymentMethod: .card),
            insertExpense("Mercadona Sur", category: groceries, paymentMethod: .card),
        ])

        let prediction = index.prediction(for: "Mercadona Gran Vía")

        #expect(prediction.category === groceries)
        #expect(prediction.paymentMethod == .card)
    }

    // Una palabra de un solo gasto, o repartida entre categorías sin una que pase del 60 %, no deduce nada.
    @Test func predictionNeedsTwoExpensesAndMoreThanSixtyPercent() {
        let food = insertCategory("Comida")
        let clothes = insertCategory("Ropa")
        let leisure = insertCategory("Ocio")
        let index = makeIndex([
            insertExpense("Ferretería Pepe", category: food, paymentMethod: .cash),
            insertExpense("Compra pan", category: food, paymentMethod: .card),
            insertExpense("Compra ropa", category: clothes, paymentMethod: .transfer),
            insertExpense("Compra libro", category: leisure, paymentMethod: .cash),
        ])

        let single = index.prediction(for: "Ferretería Luis")
        let spread = index.prediction(for: "Compra nueva")

        #expect(single.category == nil)
        #expect(single.paymentMethod == nil)
        #expect(spread.category == nil)
        #expect(spread.paymentMethod == nil)
    }

    @Test func numbersAndShortWordsDoNotPredict() {
        let leisure = insertCategory("Ocio")
        let index = makeIndex([
            insertExpense("Libro de 2024", category: leisure),
            insertExpense("Revista de 2024", category: leisure),
        ])

        #expect(index.prediction(for: "Periódico de 2024").category == nil)
    }

    @Test func tiedWordsDoNotPredict() {
        let food = insertCategory("Comida")
        let travel = insertCategory("Viajes")
        let index = makeIndex([
            insertExpense("Pizza Roma", category: food),
            insertExpense("Pizza Milano", category: food),
            insertExpense("Hotel Napoli", category: travel),
            insertExpense("Tren Napoli", category: travel),
        ])

        #expect(index.prediction(for: "Pizza Napoli").category == nil)
        #expect(index.prediction(for: "Pizza Napoli").paymentMethod == .card)
    }

    private func makeIndex(_ expenses: [Expense]) -> ExpenseSuggestionIndex {
        ExpenseSuggestionIndex(expenses: expenses, now: now)
    }

    private func insertCategory(_ name: String) -> ExpenseCategory {
        let category = ExpenseCategory(name: name, icon: .init(symbolName: "tag"), sortOrder: 0)
        context.insert(category)
        return category
    }

    @discardableResult
    private func insertExpense(
        _ title: String,
        amount: Decimal = 1,
        daysAgo: Int = 1,
        category: ExpenseCategory? = nil,
        paymentMethod: PaymentMethod = .card
    ) -> Expense {
        let date = now.addingTimeInterval(Double(-daysAgo) * 86_400)
        let expense = Expense(amount: amount, date: date, title: title, paymentMethod: paymentMethod, category: category)
        context.insert(expense)
        return expense
    }
}
