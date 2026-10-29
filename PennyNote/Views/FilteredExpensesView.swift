import SwiftUI
import SwiftData

// Gastos de un periodo que cumplen un filtro; se abre al tocar una fila de Estadísticas.
struct FilteredExpensesView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.currency) private var currency

    let title: String
    let period: StatisticsPeriod
    let filter: ExpenseFilter

    // @Query propio, no un array recibido: así la lista se actualiza al editar o borrar un gasto.
    @Query(filter: #Predicate<Expense> { !$0.isSoftDeleted }, sort: \Expense.date, order: .reverse)
    private var activeExpenses: [Expense]

    private var expenses: [Expense] {
        SpendingStatistics.expenses(activeExpenses, in: period).filter(filter.matches)
    }

    var body: some View {
        let expenses = self.expenses
        List {
            DayGroupedExpenseSections(expenses: expenses, onSelect: isReadOnly ? { _ in } : router.presentEdit)
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
                Text("\(period.title()) · \(DisplayFormat.currency(expenses.sum(of: \.amount), in: currency))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
