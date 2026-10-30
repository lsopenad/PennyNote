import SwiftUI
import SwiftData

struct AddEditExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currency) private var currency

    private let expenseToEdit: Expense?

    @State private var amount: AmountInput
    @State private var date: Date
    @State private var title: String
    @State private var paymentMethod: PaymentMethod
    @State private var category: ExpenseCategory?
    @State private var repeatFrequency: RecurrenceFrequency?

    // El gasto recurrente que creó este gasto, si sigue existiendo: como mucho uno.
    @Query private var sourceRecurringExpenses: [RecurringExpense]

    init(expense: Expense? = nil) {
        self.expenseToEdit = expense
        _amount = State(initialValue: AmountInput(expense?.amount))
        _date = State(initialValue: expense?.date ?? .now)
        _title = State(initialValue: expense?.title ?? "")
        _paymentMethod = State(initialValue: expense?.paymentMethod ?? .card)
        _category = State(initialValue: expense?.category)
        // Sin plantilla, un id que no coincide con ninguna.
        let recurringExpenseID = expense?.recurringExpenseID ?? UUID()
        _sourceRecurringExpenses = Query(filter: #Predicate { $0.id == recurringExpenseID && !$0.isSoftDeleted })
    }

    private var canSave: Bool {
        amount.isValid(for: currency)
    }

    // Repetir desde una fecha pasada crea también los gastos que faltan hasta hoy.
    private var createsPastExpenses: Bool {
        guard let repeatFrequency,
              let next = RecurrenceSchedule(frequency: repeatFrequency, startDate: date).occurrence(1) else { return false }
        return Calendar.current.startOfDay(for: next) <= Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        NavigationStack {
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
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                } footer: {
                    AmountDecimalsWarning(input: amount)
                }

                Section {
                    if let recurringExpense = sourceRecurringExpenses.first {
                        NavigationLink {
                            RecurringExpenseEditView(recurringExpense: recurringExpense)
                        } label: {
                            LabeledContent {
                                Text(recurringExpense.frequency.title)
                            } label: {
                                Label("Repetir", systemImage: "repeat")
                            }
                        }
                    } else {
                        Picker(selection: $repeatFrequency) {
                            Text("Nunca").tag(RecurrenceFrequency?.none)
                            ForEach(RecurrenceFrequency.allCases) { frequency in
                                Text(frequency.title).tag(RecurrenceFrequency?.some(frequency))
                            }
                        } label: {
                            Label("Repetir", systemImage: "repeat")
                        }
                    }
                } footer: {
                    if !sourceRecurringExpenses.isEmpty {
                        Text("Los cambios en la repetición se aplican a los próximos gastos.")
                    } else if createsPastExpenses {
                        Text("Se añadirán también los gastos de las fechas que ya han pasado.")
                    }
                }
            }
            .navigationTitle(expenseToEdit == nil ? Text("Añadir gasto") : Text("Editar gasto"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard let amount = amount.value else { return }
        // Un gasto que ya viene de un recurrente no puede empezar otro.
        let repeatFrequency = sourceRecurringExpenses.isEmpty ? repeatFrequency : nil

        if let expense = expenseToEdit {
            ExpenseRepository.updateExpense(
                expense,
                amount: amount,
                date: date,
                title: title,
                paymentMethod: paymentMethod,
                category: category,
                repeatFrequency: repeatFrequency,
                context: modelContext
            )
        } else {
            ExpenseRepository.addExpense(
                amount: amount,
                date: date,
                title: title,
                paymentMethod: paymentMethod,
                category: category,
                repeatFrequency: repeatFrequency,
                context: modelContext
            )
        }

        dismiss()
    }
}
