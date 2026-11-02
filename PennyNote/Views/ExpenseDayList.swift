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

    @Query(filter: #Predicate<Expense> { !$0.isSoftDeleted }, sort: \Expense.date, order: .reverse)
    private var activeExpenses: [Expense]

    @State private var limit = Self.pageSize
    @State private var expenseToDelete: Expense?
    @State private var isDeleteConfirmationPresented = false

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
                onDeleteRequest: { expense in
                    expenseToDelete = expense
                    isDeleteConfirmationPresented = true
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
        // Un solo diálogo para toda la lista: uno por fila tenía el mismo coste que swipeActions.
        .confirmationDialog(
            Text("¿Eliminar «\(expenseToDelete.map(Self.displayName) ?? "")»?", comment: "Confirmación al borrar deslizando; el nombre es el gasto, la categoría o el gasto recurrente"),
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible,
            presenting: expenseToDelete
        ) { expense in
            Button("Eliminar", role: .destructive) {
                ExpenseRepository.deleteExpense(expense, context: modelContext)
            }
            Button("Cancelar", role: .cancel) {}
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

    // El nombre que se ve en la fila: el título o, sin él, la categoría.
    private static func displayName(_ expense: Expense) -> String {
        expense.title.isEmpty ? expense.category.displayName : expense.title
    }

    // Solo el filtro: los datos llegan por el @Query y el entorno.
    static func == (lhs: ExpenseDayList, rhs: ExpenseDayList) -> Bool {
        lhs.filter == rhs.filter
    }
}
