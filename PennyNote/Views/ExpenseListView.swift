import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(SyncCoordinator.self) private var sync
    @Environment(\.isReadOnly) private var isReadOnly

    @Query(filter: #Predicate<Expense> { !$0.isSoftDeleted }, sort: \Expense.date, order: .reverse)
    private var activeExpenses: [Expense]

    @Namespace private var searchAnimation
    @State private var isSearchActive = false

    @State private var filter = ExpenseFilter()

    private var filteredExpenses: [Expense] {
        activeExpenses.filter(filter.matches)
    }

    var body: some View {
        @Bindable var router = router
        ZStack {
            NavigationStack(path: $router.navigationPath) {
                ZStack(alignment: .bottomTrailing) {
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

                        DayGroupedExpenseSections(
                            expenses: filteredExpenses,
                            onSelect: isReadOnly ? { _ in } : router.presentEdit,
                            onDelete: isReadOnly ? nil : { expense in
                                ExpenseRepository.deleteExpense(expense, context: modelContext)
                            }
                        )
                    }
                    .listStyle(.plain)
                    .refreshable {
                        guard !isReadOnly else { return }
                        await sync.syncNow()
                    }

                    if !isReadOnly {
                        addButton
                    }
                }
                .navigationTitle("PennyNote")
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .statistics:
                        StatisticsView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.snappy) { isSearchActive = true }
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .matchedGeometryEffect(id: "searchAnchor", in: searchAnimation)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ExpenseFilterMenu(filter: $filter)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .opacity(isSearchActive ? 0 : 1)

            if isSearchActive {
                ExpenseSearchOverlay(
                    expenses: activeExpenses,
                    namespace: searchAnimation,
                    onSelect: { expense in
                        withAnimation(.snappy) { isSearchActive = false }
                        if !isReadOnly {
                            router.presentEdit(expense)
                        }
                    },
                    onCancel: {
                        withAnimation(.snappy) { isSearchActive = false }
                    }
                )
                .zIndex(1)
            }
        }
        // La búsqueda solo se abre desde la lista, así que si cambia la ruta con ella abierta es por
        // un enlace (el widget abre Estadísticas). Se cierra para que no tape la pantalla de destino.
        .onChange(of: router.navigationPath) { _, path in
            if !path.isEmpty, isSearchActive {
                isSearchActive = false
            }
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

    private var addButton: some View {
        Button(action: router.presentAdd) {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.tint, in: Circle())
                .shadow(radius: 4, y: 2)
        }
        .padding(20)
    }
}
