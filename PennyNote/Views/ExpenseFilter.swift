import Foundation

// Filtro de la lista de gastos. Dentro de cada grupo (categoría, método de pago) las opciones
// marcadas se combinan con "o"; entre grupos, con "y". Un grupo sin nada marcado no filtra.
struct ExpenseFilter {
    var categoryIDs: Set<UUID> = []
    var includesUncategorized = false
    var paymentMethods: Set<PaymentMethod> = []

    var isActive: Bool {
        !categoryIDs.isEmpty || includesUncategorized || !paymentMethods.isEmpty
    }

    func matches(_ expense: Expense) -> Bool {
        matchesCategory(of: expense) && (paymentMethods.isEmpty || paymentMethods.contains(expense.paymentMethod))
    }

    mutating func clear() {
        self = ExpenseFilter()
    }

    private func matchesCategory(of expense: Expense) -> Bool {
        guard !categoryIDs.isEmpty || includesUncategorized else { return true }
        guard let category = expense.category else { return includesUncategorized }
        return categoryIDs.contains(category.id)
    }
}
