import Foundation

// Categoría y método de pago deducidos del título; nil en lo que no se ha podido deducir.
struct ExpenseFieldPrediction {
    var category: ExpenseCategory?
    var paymentMethod: PaymentMethod?

    static let none = ExpenseFieldPrediction()
}
