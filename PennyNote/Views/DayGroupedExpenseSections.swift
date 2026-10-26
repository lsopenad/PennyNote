import SwiftUI

// Secciones de una List con los gastos agrupados por día, del más reciente al más antiguo.
// Dentro de cada día se respeta el orden en que llegan los gastos.
struct DayGroupedExpenseSections: View {
    let expenses: [Expense]
    let onSelect: (Expense) -> Void
    // nil desactiva el borrado deslizando.
    var onDelete: ((_ dayItems: [Expense], _ offsets: IndexSet) -> Void)?

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
                    ExpenseRowView(expense: expense)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(expense) }
                }
                .onDelete(perform: onDelete.map { handler in { offsets in handler(group.items, offsets) } })
            }
        }
    }
}
