import SwiftUI

struct ExpenseSearchOverlay: View {
    let expenses: [Expense]
    let namespace: Namespace.ID
    let onSelect: (Expense) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @FocusState private var isFieldFocused: Bool

    private var filteredExpenses: [Expense] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return expenses.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            ($0.category?.name.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private var groupedResults: [(day: Date, items: [Expense])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredExpenses) { calendar.startOfDay(for: $0.date) }
        return groups
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, items: $0.value) }
    }

    var body: some View {
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

                Button("Cancelar", action: onCancel)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if !filteredExpenses.isEmpty {
                List {
                    ForEach(groupedResults, id: \.day) { group in
                        Section(header: Text(group.day, style: .date)) {
                            ForEach(group.items) { expense in
                                ExpenseRowView(expense: expense)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onSelect(expense) }
                            }
                        }
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
    }
}
