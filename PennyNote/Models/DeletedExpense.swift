import Foundation

// Copia de un gasto recién borrado, para poder deshacer el borrado. Guarda los datos y no el gasto:
// en cuanto el borrado llega al servidor, la sincronización quita el gasto del móvil.
struct DeletedExpense: Identifiable, Equatable {
    let id: UUID
    let amount: Decimal
    let date: Date
    let title: String
    let paymentMethod: PaymentMethod
    let categoryID: UUID?
    let recurringExpenseID: UUID?
    let createdAt: Date
    // El nombre que se ve en la fila: el título o, sin él, la categoría.
    let displayName: String

    init(_ expense: Expense) {
        id = expense.id
        amount = expense.amount
        date = expense.date
        title = expense.title
        paymentMethod = expense.paymentMethod
        categoryID = expense.category?.id
        recurringExpenseID = expense.recurringExpenseID
        createdAt = expense.createdAt
        displayName = expense.title.isEmpty ? expense.category.displayName : expense.title
    }
}
