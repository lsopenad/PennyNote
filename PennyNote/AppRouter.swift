import Foundation
import Observation

@Observable
final class AppRouter {
    var isAddExpensePresented = false
    var expenseToEdit: Expense?

    func presentAdd() {
        expenseToEdit = nil
        isAddExpensePresented = true
    }

    func presentEdit(_ expense: Expense) {
        expenseToEdit = expense
        isAddExpensePresented = true
    }
}
