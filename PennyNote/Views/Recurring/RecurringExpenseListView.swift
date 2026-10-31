import SwiftUI
import SwiftData

// Ajustes → Gastos recurrentes.
struct RecurringExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<RecurringExpense> { !$0.isSoftDeleted }, sort: \RecurringExpense.nextDate)
    private var recurringExpenses: [RecurringExpense]

    var body: some View {
        List {
            ForEach(recurringExpenses) { recurringExpense in
                NavigationLink {
                    RecurringExpenseEditView(recurringExpense: recurringExpense)
                } label: {
                    RecurringExpenseRow(recurringExpense: recurringExpense)
                }
                .swipeToDelete(
                    name: recurringExpense.title.isEmpty ? recurringExpense.category.displayName : recurringExpense.title,
                    message: "No se crearán más gastos. Los que ya ha creado se conservan."
                ) {
                    ExpenseRepository.deleteRecurringExpense(recurringExpense, context: modelContext)
                }
            }
        }
        .overlay {
            if recurringExpenses.isEmpty {
                ContentUnavailableView {
                    Label("Sin gastos recurrentes", systemImage: "repeat")
                } description: {
                    Text("Elige «Repetir» al añadir un gasto para que se apunte solo cada semana, mes o año.")
                }
            }
        }
        .navigationTitle("Gastos recurrentes")
    }
}
