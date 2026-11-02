import Foundation

// Un gasto anterior que se propone al escribir el título: el más reciente de los que tienen ese título.
struct ExpenseSuggestion: Identifiable {
    // El título normalizado, que agrupa los gastos con el mismo título.
    let id: String
    let title: String
    let amount: Decimal
    let category: ExpenseCategory?
    let paymentMethod: PaymentMethod
}
