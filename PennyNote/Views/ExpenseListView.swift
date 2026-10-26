import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @Query(filter: #Predicate<Expense> { !$0.isDeleted }, sort: \Expense.date, order: .reverse)
    private var activeExpenses: [Expense]

    @Namespace private var searchAnimation
    @State private var isSearchActive = false

    @State private var filter = ExpenseFilter()

    @State private var pendingDeletion: (items: [Expense], offsets: IndexSet)?
    @State private var isDeleteConfirmationPresented = false

    private var filteredExpenses: [Expense] {
        activeExpenses.filter(filter.matches)
    }

    private var monthlyTotal: Decimal {
        MonthlyTotalCalculator.total(in: modelContext)
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ZStack(alignment: .bottomTrailing) {
                    List {
                        Section {
                            MonthHeaderView(total: monthlyTotal)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                        }

                        DayGroupedExpenseSections(
                            expenses: filteredExpenses,
                            onSelect: router.presentEdit,
                            onDelete: { items, offsets in
                                pendingDeletion = (items, offsets)
                                isDeleteConfirmationPresented = true
                            }
                        )
                    }
                    .listStyle(.plain)

                    addButton
                }
                .navigationTitle("PennyNote")
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
                .confirmationDialog(
                    "¿Eliminar gasto?",
                    isPresented: $isDeleteConfirmationPresented,
                    titleVisibility: .visible
                ) {
                    Button("Eliminar", role: .destructive) { confirmPendingDeletion() }
                    Button("Cancelar", role: .cancel) { pendingDeletion = nil }
                }
            }
            .opacity(isSearchActive ? 0 : 1)

            if isSearchActive {
                ExpenseSearchOverlay(
                    expenses: activeExpenses,
                    namespace: searchAnimation,
                    onSelect: { expense in
                        withAnimation(.snappy) { isSearchActive = false }
                        router.presentEdit(expense)
                    },
                    onCancel: {
                        withAnimation(.snappy) { isSearchActive = false }
                    }
                )
                .zIndex(1)
            }
        }
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

    private func confirmPendingDeletion() {
        guard let pendingDeletion else { return }
        for index in pendingDeletion.offsets {
            ExpenseRepository.deleteExpense(pendingDeletion.items[index], context: modelContext)
        }
        self.pendingDeletion = nil
    }
}
