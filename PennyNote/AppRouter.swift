import Foundation
import Observation

@Observable
final class AppRouter {
    var isAddExpensePresented = false
    var expenseToEdit: Expense?
    var navigationPath: [AppRoute] = []

    func presentAdd() {
        expenseToEdit = nil
        isAddExpensePresented = true
    }

    func presentEdit(_ expense: Expense) {
        expenseToEdit = expense
        isAddExpensePresented = true
    }

    // Desde un enlace profundo puede llegar con Estadísticas ya abierta: no se apila otra vez.
    func presentStatistics() {
        guard navigationPath.last != .statistics else { return }
        navigationPath.append(.statistics)
    }
}

enum AppRoute: Hashable {
    case statistics
}
