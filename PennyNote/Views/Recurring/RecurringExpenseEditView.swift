import SwiftUI
import SwiftData

// Editar, pausar o borrar un gasto recurrente. Los cambios solo afectan a los gastos que se creen a
// partir de ahora.
struct RecurringExpenseEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currency) private var currency

    let recurringExpense: RecurringExpense

    @State private var amount: AmountInput
    @State private var title: String
    @State private var paymentMethod: PaymentMethod
    @State private var category: ExpenseCategory?
    @State private var frequency: RecurrenceFrequency
    @State private var nextDate: Date
    @State private var isPaused: Bool
    @State private var isDeleteConfirmationPresented = false

    init(recurringExpense: RecurringExpense) {
        self.recurringExpense = recurringExpense
        _amount = State(initialValue: AmountInput(recurringExpense.amount))
        _title = State(initialValue: recurringExpense.title)
        _paymentMethod = State(initialValue: recurringExpense.paymentMethod)
        _category = State(initialValue: recurringExpense.category)
        _frequency = State(initialValue: recurringExpense.frequency)
        _nextDate = State(initialValue: recurringExpense.nextDate)
        _isPaused = State(initialValue: recurringExpense.isPaused)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Título")
                    TextField("", text: $title)
                }
                AmountField(input: $amount)
                CategoryPickerView(selection: $category)
                Picker("Método de pago", selection: $paymentMethod) {
                    ForEach(PaymentMethod.allCases) { method in
                        Text(method.title).tag(method)
                    }
                }
            } footer: {
                AmountDecimalsWarning(input: amount)
            }

            Section {
                Picker("Repetir", selection: $frequency) {
                    ForEach(RecurrenceFrequency.allCases) { frequency in
                        Text(frequency.title).tag(frequency)
                    }
                }
                if !isPaused {
                    DatePicker("Próximo gasto", selection: $nextDate, displayedComponents: .date)
                }
                Toggle("En pausa", isOn: $isPaused)
            } footer: {
                if isPaused {
                    Text("En pausa no se crean gastos. Al reanudarlo, sigue desde la próxima fecha sin añadir los que no se crearon.")
                } else {
                    Text("Los cambios se aplican a los próximos gastos; los ya creados no cambian.")
                }
            }

            Section {
                Button("Eliminar gasto recurrente", role: .destructive) {
                    isDeleteConfirmationPresented = true
                }
            } footer: {
                Text("Los gastos que ya ha creado se conservan.")
            }
        }
        .navigationTitle("Gasto recurrente")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar", action: save)
                    .disabled(!amount.isValid(for: currency))
            }
        }
        .onChange(of: isPaused) { wasPaused, isPaused in
            // Al reanudar se propone la próxima fecha de la serie, no la que tocaba al pausarla.
            if wasPaused, !isPaused, recurringExpense.isPaused {
                nextDate = ExpenseRepository.resumedNextDate(of: recurringExpense)
            }
        }
        .confirmationDialog(
            "¿Eliminar gasto recurrente?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive, action: delete)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("No se crearán más gastos. Los que ya ha creado se conservan.")
        }
    }

    private func save() {
        guard let amount = amount.value else { return }
        ExpenseRepository.updateRecurringExpense(
            recurringExpense,
            amount: amount,
            title: title,
            paymentMethod: paymentMethod,
            category: category,
            frequency: frequency,
            nextDate: nextDate,
            isPaused: isPaused,
            context: modelContext
        )
        dismiss()
    }

    private func delete() {
        ExpenseRepository.deleteRecurringExpense(recurringExpense, context: modelContext)
        dismiss()
    }
}
