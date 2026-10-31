import SwiftUI

// Secciones de una List con los gastos agrupados por día, del más reciente al más antiguo.
// Dentro de cada día se respeta el orden en que llegan los gastos.
struct DayGroupedExpenseSections: View {
    let expenses: [Expense]
    let onSelect: (Expense) -> Void
    // nil desactiva el borrado deslizando.
    var onDelete: ((Expense) -> Void)?

    private var groups: [(day: Date, items: [Expense])] {
        let calendar = Calendar.current
        return Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, items: $0.value) }
    }

    var body: some View {
        ForEach(groups, id: \.day) { group in
            Section(header: Text(group.day, style: .date)) {
                ForEach(group.items) { expense in
                    row(for: expense)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for expense: Expense) -> some View {
        let row = ExpenseRowView(expense: expense)
            .contentShape(Rectangle())
            .onTapGesture { onSelect(expense) }
        if let onDelete {
            // El nombre que se ve en la fila: el título o, sin él, la categoría.
            row.swipeToDelete(name: expense.title.isEmpty ? expense.category.displayName : expense.title) {
                onDelete(expense)
            }
        } else {
            row
        }
    }
}
