import Foundation
import Testing
@testable import PennyNote

@MainActor
struct ExpenseAutofillTests {
    private let groceries = ExpenseCategory(name: "Supermercado", icon: .init(symbolName: "cart"), sortOrder: 0)
    private let leisure = ExpenseCategory(name: "Ocio", icon: .init(symbolName: "film"), sortOrder: 1)

    private var title = ""
    private var amount = AmountInput()
    private var category: ExpenseCategory?
    private var paymentMethod = PaymentMethod.card
    private var autofill = ExpenseAutofill(initialPaymentMethod: .card)

    @Test mutating func suggestionFillsEverythingTheUserHasNotChanged() {
        amount.text = "5"

        applySuggestion(ExpenseSuggestion(id: "mercadona", title: "Mercadona", amount: 42, category: groceries, paymentMethod: .cash))

        #expect(title == "Mercadona")
        #expect(amount.text == "5")
        #expect(category === groceries)
        #expect(paymentMethod == .cash)
        #expect(!autofill.isPredicted(category))
    }

    // El importe de un gasto rápido pendiente lo escribió el usuario: no se pisa.
    @Test mutating func suggestionKeepsTheAmountOfAPendingExpense() {
        amount = AmountInput(12)

        applySuggestion(ExpenseSuggestion(id: "cafe", title: "Café", amount: 1.5, category: nil, paymentMethod: .card))

        #expect(amount.value == 12)
    }

    @Test mutating func choosingAnotherSuggestionReplacesWhatTheFirstFilled() {
        applySuggestion(ExpenseSuggestion(id: "cine", title: "Cine", amount: 9, category: leisure, paymentMethod: .cash))
        applySuggestion(ExpenseSuggestion(id: "mercadona", title: "Mercadona", amount: 42, category: groceries, paymentMethod: .transfer))

        #expect(amount.value == 42)
        #expect(category === groceries)
        #expect(paymentMethod == .transfer)
    }

    @Test mutating func predictionFillsUntouchedFieldsAndUndoesItWhenItNoLongerApplies() {
        applyPrediction(ExpenseFieldPrediction(category: groceries, paymentMethod: .cash), forTitle: "Mercadona Sur")

        #expect(category === groceries)
        #expect(paymentMethod == .cash)
        #expect(autofill.isPredicted(category))
        #expect(autofill.isPredicted(paymentMethod))

        applyPrediction(.none, forTitle: "Algo nuevo")

        #expect(category == nil)
        #expect(paymentMethod == .card)
        #expect(!autofill.isPredicted(category))
        #expect(!autofill.isPredicted(paymentMethod))
    }

    @Test mutating func predictionDoesNotOverwriteTheUsersChoice() {
        category = leisure
        paymentMethod = .transfer

        applyPrediction(ExpenseFieldPrediction(category: groceries, paymentMethod: .cash), forTitle: "Mercadona")

        #expect(category === leisure)
        #expect(paymentMethod == .transfer)
        #expect(!autofill.isPredicted(category))
        #expect(!autofill.isPredicted(paymentMethod))
    }

    @Test mutating func changingAPredictedFieldRemovesTheSuggestedNote() {
        applyPrediction(ExpenseFieldPrediction(category: groceries, paymentMethod: nil), forTitle: "Mercadona")
        category = leisure

        #expect(!autofill.isPredicted(category))

        applyPrediction(ExpenseFieldPrediction(category: groceries, paymentMethod: nil), forTitle: "Mercadona Sur")

        #expect(category === leisure)
    }

    // Lo que se dedujo antes no marca como «sugerido» un valor que el usuario vuelve a elegir a mano.
    @Test mutating func predictionThatCannotFillForgetsThePreviousOne() {
        applyPrediction(ExpenseFieldPrediction(category: nil, paymentMethod: .cash), forTitle: "Mercadona")
        paymentMethod = .transfer
        applyPrediction(ExpenseFieldPrediction(category: nil, paymentMethod: .cash), forTitle: "Mercadona Sur")
        paymentMethod = .cash

        #expect(!autofill.isPredicted(paymentMethod))
    }

    // Elegir una sugerencia cambia el título: la deducción que llega después no la sustituye.
    @Test mutating func predictionAfterChoosingASuggestionKeepsItsValues() {
        applySuggestion(ExpenseSuggestion(id: "cine", title: "Cine", amount: 9, category: leisure, paymentMethod: .cash))

        applyPrediction(ExpenseFieldPrediction(category: groceries, paymentMethod: .transfer), forTitle: "cine")

        #expect(category === leisure)
        #expect(paymentMethod == .cash)
        #expect(!autofill.isPredicted(category))
    }

    private mutating func applySuggestion(_ suggestion: ExpenseSuggestion) {
        autofill.apply(suggestion, title: &title, amount: &amount, category: &category, paymentMethod: &paymentMethod)
    }

    private mutating func applyPrediction(_ prediction: ExpenseFieldPrediction, forTitle title: String) {
        autofill.apply(prediction, forTitle: title, category: &category, paymentMethod: &paymentMethod)
    }
}
