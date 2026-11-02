import SwiftUI
import SwiftData

struct ExpenseSearchOverlay: View {
    // Propio y no recibido de la lista: así solo se cargan los gastos mientras la búsqueda está abierta.
    @Query(filter: #Predicate<Expense> { !$0.isSoftDeleted }, sort: \Expense.date, order: .reverse)
    private var expenses: [Expense]

    let namespace: Namespace.ID
    let onSelect: (Expense) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @State private var limit = ExpenseDayList.pageSize
    @FocusState private var isFieldFocused: Bool

    // Gastos cuyo título o categoría contienen el texto, en el orden en que llegan. Sin texto, ninguno.
    static func results(_ expenses: [Expense], matching searchText: String) -> [Expense] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return expenses.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            ($0.category?.name.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        let results = Self.results(expenses, matching: searchText)
        let visible = ExpenseDayList.visibleExpenses(results, limit: limit)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Buscar gastos", text: $searchText)
                        .focused($isFieldFocused)
                        .submitLabel(.search)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .matchedGeometryEffect(id: "searchAnchor", in: namespace)

                Button("Cancelar") { close(then: onCancel) }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if !results.isEmpty {
                List {
                    DayGroupedExpenseSections(expenses: visible, onSelect: { expense in
                        close { onSelect(expense) }
                    })
                    if visible.count < results.count {
                        Section {
                            Button("Mostrar más") { limit += ExpenseDayList.pageSize }
                                .foregroundStyle(.tint)
                                .frame(maxWidth: .infinity)
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            } else {
                Spacer()
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .bottom)
        .onAppear { isFieldFocused = true }
        .onChange(of: searchText) {
            limit = ExpenseDayList.pageSize
        }
    }

    // Suelta el foco antes de cerrar para que el teclado baje a la vez que se va la búsqueda. Si el
    // campo desaparece con el foco puesto, el teclado se queda encima de la lista y luego se va de golpe.
    private func close(then action: () -> Void) {
        isFieldFocused = false
        action()
    }
}
