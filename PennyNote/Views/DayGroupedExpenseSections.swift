import SwiftUI

// Secciones de una List con los gastos agrupados por día, del más reciente al más antiguo.
// Dentro de cada día se respeta el orden en que llegan los gastos.
struct DayGroupedExpenseSections: View {
    let expenses: [Expense]
    let onSelect: (Expense) -> Void
    // Al deslizar para borrar; quien la usa borra el gasto. nil desactiva el borrado deslizando.
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
                // onDelete del ForEach y no swipeActions en cada fila: con miles de filas, el modificador
                // por fila hacía que cada actualización de la lista tardara segundos.
                ForEach(group.items) { expense in
                    ExpenseRowView(expense: expense)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(expense) }
                }
                .onDelete(perform: onDelete.map { delete in
                    { offsets in offsets.map { group.items[$0] }.forEach(delete) }
                })
            }
        }
    }
}
