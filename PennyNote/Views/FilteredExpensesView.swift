import SwiftUI
import SwiftData

// Gastos de un mes que cumplen un filtro; se abre al tocar una fila de Estadísticas.
struct FilteredExpensesView: View {
    @Environment(AppRouter.self) private var router

    let title: String
    let month: Date
    let filter: ExpenseFilter

    // @Query propio, no un array recibido: así la lista se actualiza al editar o borrar un gasto.
    @Query(filter: #Predicate<Expense> { !$0.isSoftDeleted }, sort: \Expense.date, order: .reverse)
    private var activeExpenses: [Expense]

    private var expenses: [Expense] {
        SpendingStatistics.expenses(activeExpenses, inMonthOf: month).filter(filter.matches)
    }

    var body: some View {
        let expenses = self.expenses
        List {
            DayGroupedExpenseSections(expenses: expenses, onSelect: router.presentEdit)
        }
        .listStyle(.plain)
        .overlay {
            if expenses.isEmpty {
                ContentUnavailableView("Sin gastos", systemImage: "tray")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .status) {
                Text("\(DisplayFormat.monthAndYear(month)) · \(DisplayFormat.currency(expenses.reduce(.zero) { $0 + $1.amount }))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
