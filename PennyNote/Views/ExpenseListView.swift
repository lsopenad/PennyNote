import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @Namespace private var searchAnimation
    @State private var isSearchActive = false

    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var includeUncategorized = false
    @State private var selectedPaymentMethods: Set<PaymentMethod> = []

    @State private var pendingDeletion: (items: [Expense], offsets: IndexSet)?
    @State private var isDeleteConfirmationPresented = false

    private var notDeletedExpenses: [Expense] {
        allExpenses.filter { !$0.isDeleted }
    }

    private var hasActiveFilters: Bool {
        !selectedCategoryIDs.isEmpty || includeUncategorized || !selectedPaymentMethods.isEmpty
    }

    private var expenses: [Expense] {
        notDeletedExpenses.filter { matchesFilters($0) }
    }

    private var groupedExpenses: [(day: Date, items: [Expense])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
        return groups
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, items: $0.value) }
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

                        ForEach(groupedExpenses, id: \.day) { group in
                            Section(header: Text(group.day, style: .date)) {
                                ForEach(group.items) { expense in
                                    ExpenseRowView(expense: expense)
                                        .contentShape(Rectangle())
                                        .onTapGesture { router.presentEdit(expense) }
                                }
                                .onDelete { offsets in
                                    pendingDeletion = (group.items, offsets)
                                    isDeleteConfirmationPresented = true
                                }
                            }
                        }
                    }
                    .listStyle(.plain)

                    Button(action: { router.presentAdd() }) {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(.tint, in: Circle())
                            .shadow(radius: 4, y: 2)
                    }
                    .padding(20)
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
                        filterMenu
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
                    expenses: notDeletedExpenses,
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

    private var filterMenu: some View {
        Menu {
            Section("Categoría") {
                ForEach(categories) { category in
                    Toggle(isOn: categoryFilterBinding(for: category.id)) {
                        Label(category.name, systemImage: category.symbolName)
                    }
                }
                Toggle("Sin categoría", isOn: $includeUncategorized)
            }
            Section("Método de pago") {
                ForEach(PaymentMethod.allCases) { method in
                    Toggle(method.rawValue, isOn: paymentMethodFilterBinding(for: method))
                }
            }
            if hasActiveFilters {
                Divider()
                Button("Limpiar filtros", role: .destructive) { clearFilters() }
            }
        } label: {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    private func categoryFilterBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedCategoryIDs.contains(id) },
            set: { isOn in
                if isOn { selectedCategoryIDs.insert(id) } else { selectedCategoryIDs.remove(id) }
            }
        )
    }

    private func paymentMethodFilterBinding(for method: PaymentMethod) -> Binding<Bool> {
        Binding(
            get: { selectedPaymentMethods.contains(method) },
            set: { isOn in
                if isOn { selectedPaymentMethods.insert(method) } else { selectedPaymentMethods.remove(method) }
            }
        )
    }

    private func clearFilters() {
        selectedCategoryIDs.removeAll()
        includeUncategorized = false
        selectedPaymentMethods.removeAll()
    }

    private func matchesFilters(_ expense: Expense) -> Bool {
        let categoryMatches: Bool
        if selectedCategoryIDs.isEmpty && !includeUncategorized {
            categoryMatches = true
        } else if let category = expense.category {
            categoryMatches = selectedCategoryIDs.contains(category.id)
        } else {
            categoryMatches = includeUncategorized
        }

        let paymentMatches = selectedPaymentMethods.isEmpty || selectedPaymentMethods.contains(expense.paymentMethod)

        return categoryMatches && paymentMatches
    }

    private func confirmPendingDeletion() {
        guard let pendingDeletion else { return }
        delete(pendingDeletion.items, at: pendingDeletion.offsets)
        self.pendingDeletion = nil
    }

    private func delete(_ items: [Expense], at offsets: IndexSet) {
        for index in offsets {
            ExpenseRepository.deleteExpense(items[index], context: modelContext)
        }
    }
}
