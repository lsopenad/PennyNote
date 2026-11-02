import SwiftUI
import SwiftData

// Lista de la pantalla principal: la cabecera del mes y los gastos por día. Va aparte de
// ExpenseListView para que abrir la búsqueda o navegar no la vuelva a evaluar, y muestra los gastos
// por páginas: con miles de filas, cada actualización de la lista bloqueaba la app.
struct ExpenseDayList: View, Equatable {
    static let pageSize = 200

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(SyncCoordinator.self) private var sync

    let filter: ExpenseFilter
    let onShowNeedsDetails: () -> Void
    // Tras borrar un gasto deslizando, con la copia para deshacerlo.
    let onDeleted: (DeletedExpense) -> Void

    @Query(filter: #Predicate<Expense> { !$0.isSoftDeleted }, sort: \Expense.date, order: .reverse)
    private var activeExpenses: [Expense]

    @State private var limit = Self.pageSize

    var body: some View {
        let filtered = activeExpenses.filter(filter.matches)
        let visible = Self.visibleExpenses(filtered, limit: limit)
        List {
            Section {
                Button(action: router.presentStatistics) {
                    monthHeader
                }
                .buttonStyle(.plain)
                .accessibilityHint("Abre las estadísticas")
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }

            needsDetailsNotice

            DayGroupedExpenseSections(
                expenses: visible,
                onSelect: router.presentEdit,
                // Sin confirmación: el borrado se puede deshacer desde el aviso que muestra quien la usa.
                onDelete: { expense in
                    onDeleted(ExpenseRepository.deleteExpense(expense, context: modelContext))
                }
            )

            if visible.count < filtered.count {
                Section {
                    Button("Mostrar más") { limit += Self.pageSize }
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity)
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await sync.syncNow()
        }
        .onChange(of: filter) {
            limit = Self.pageSize
        }
    }

    // Aviso de gastos rápidos sin completar. Cuenta todos, no solo los del filtro, y se oculta
    // cuando ya se están mostrando solo esos.
    @ViewBuilder
    private var needsDetailsNotice: some View {
        let count = filter.onlyNeedsDetails ? 0 : activeExpenses.count(where: \.needsDetails)
        if count > 0 {
            Section {
                Button(action: onShowNeedsDetails) {
                    Label {
                        Text("Tienes \(count) gastos por completar")
                    } icon: {
                        Image(systemName: Expense.needsDetailsSymbolName)
                    }
                    .foregroundStyle(.orange)
                }
                .accessibilityHint("Muestra solo los gastos por completar")
            }
            .listRowSeparator(.hidden)
        }
    }

    // La cabecera ignora el filtro de la lista: siempre muestra el gasto total del mes.
    private var monthHeader: some View {
        let now = Date.now
        let previousMonth = Calendar.current.startOfPreviousMonth(for: now) ?? now
        return MonthHeaderView(
            current: SpendingStatistics.monthSpending(activeExpenses, monthOf: now),
            previous: SpendingStatistics.monthSpending(activeExpenses, monthOf: previousMonth),
            today: Calendar.current.component(.day, from: now)
        )
    }

    // Los `limit` más recientes, alargados hasta acabar el día del último para no cortar un día a
    // medias. `expenses` llega del más reciente al más antiguo.
    static func visibleExpenses(_ expenses: [Expense], limit: Int, calendar: Calendar = .current) -> [Expense] {
        guard limit > 0, expenses.count > limit else { return expenses }
        let lastDay = calendar.startOfDay(for: expenses[limit - 1].date)
        let end = expenses[limit...].firstIndex { calendar.startOfDay(for: $0.date) != lastDay } ?? expenses.endIndex
        return Array(expenses[..<end])
    }

    // Solo el filtro: los datos llegan por el @Query y el entorno.
    static func == (lhs: ExpenseDayList, rhs: ExpenseDayList) -> Bool {
        lhs.filter == rhs.filter
    }
}
