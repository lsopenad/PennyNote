import SwiftUI
import SwiftData

// Ajustes → Gastos recurrentes.
struct RecurringExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<RecurringExpense> { !$0.isSoftDeleted }, sort: \RecurringExpense.nextDate)
    private var recurringExpenses: [RecurringExpense]

    @State private var pendingDeletion: RecurringExpense?
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        List {
            ForEach(recurringExpenses) { recurringExpense in
                NavigationLink {
                    RecurringExpenseEditView(recurringExpense: recurringExpense)
                } label: {
                    RecurringExpenseRow(recurringExpense: recurringExpense)
                }
            }
            .onDelete { offsets in
                pendingDeletion = offsets.first.map { recurringExpenses[$0] }
                isDeleteConfirmationPresented = pendingDeletion != nil
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
        .confirmationDialog(
            "¿Eliminar gasto recurrente?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { recurringExpense in
            Button("Eliminar", role: .destructive) {
                ExpenseRepository.deleteRecurringExpense(recurringExpense, context: modelContext)
            }
            Button("Cancelar", role: .cancel) {}
        } message: { _ in
            Text("No se crearán más gastos. Los que ya ha creado se conservan.")
        }
    }
}
