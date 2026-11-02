import Foundation

// Lo que han rellenado solas las sugerencias en el formulario de gasto, para no pisar lo que haya escrito
// el usuario. Un campo se puede rellenar si sigue vacío o con su valor inicial, o si tiene lo último que
// se rellenó solo; si el usuario lo cambia, ya no se toca.
struct ExpenseAutofill {
    private let initialPaymentMethod: PaymentMethod
    private var filledAmountText: String?
    private var filledCategoryID: UUID?
    private var filledPaymentMethod: PaymentMethod?
    // El título de la sugerencia elegida, normalizado: mientras no cambie, no se deduce nada más.
    private var appliedSuggestionKey: String?
    private var predictedCategoryID: UUID?
    private var predictedPaymentMethod: PaymentMethod?

    init(initialPaymentMethod: PaymentMethod) {
        self.initialPaymentMethod = initialPaymentMethod
    }

    // Al elegir una sugerencia: el título siempre, y el importe, la categoría y el método de pago si el
    // usuario no los ha cambiado. La fecha nunca.
    mutating func apply(
        _ suggestion: ExpenseSuggestion,
        title: inout String,
        amount: inout AmountInput,
        category: inout ExpenseCategory?,
        paymentMethod: inout PaymentMethod
    ) {
        title = suggestion.title
        appliedSuggestionKey = ExpenseSuggestionIndex.normalized(suggestion.title)
        predictedCategoryID = nil
        predictedPaymentMethod = nil

        if canFill(amount) {
            amount = AmountInput(suggestion.amount)
            filledAmountText = amount.text
        }
        if canFill(category) {
            category = suggestion.category
            filledCategoryID = suggestion.category?.id
        }
        if canFill(paymentMethod) {
            paymentMethod = suggestion.paymentMethod
            filledPaymentMethod = suggestion.paymentMethod
        }
    }

    // Al dejar de escribir el título: la categoría y el método de pago deducidos, si el usuario no los ha
    // cambiado. Lo que se dedujo para un título anterior y ya no se deduce vuelve a su valor inicial.
    mutating func apply(
        _ prediction: ExpenseFieldPrediction,
        forTitle title: String,
        category: inout ExpenseCategory?,
        paymentMethod: inout PaymentMethod
    ) {
        if let appliedSuggestionKey, appliedSuggestionKey == ExpenseSuggestionIndex.normalized(title) { return }
        appliedSuggestionKey = nil

        if canFill(category) {
            category = prediction.category
            filledCategoryID = prediction.category?.id
            predictedCategoryID = prediction.category?.id
        } else {
            predictedCategoryID = nil
        }
        if canFill(paymentMethod) {
            paymentMethod = prediction.paymentMethod ?? initialPaymentMethod
            filledPaymentMethod = prediction.paymentMethod
            predictedPaymentMethod = prediction.paymentMethod
        } else {
            predictedPaymentMethod = nil
        }
    }

    // Para el aviso «sugerido»: el campo tiene lo deducido y el usuario no lo ha cambiado.
    func isPredicted(_ category: ExpenseCategory?) -> Bool {
        guard let predictedCategoryID else { return false }
        return category?.id == predictedCategoryID
    }

    func isPredicted(_ paymentMethod: PaymentMethod) -> Bool {
        predictedPaymentMethod == paymentMethod
    }

    private func canFill(_ amount: AmountInput) -> Bool {
        amount.text.isEmpty || amount.text == filledAmountText
    }

    private func canFill(_ category: ExpenseCategory?) -> Bool {
        guard let category else { return true }
        return category.id == filledCategoryID
    }

    private func canFill(_ paymentMethod: PaymentMethod) -> Bool {
        paymentMethod == initialPaymentMethod || paymentMethod == filledPaymentMethod
    }
}
