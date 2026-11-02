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

    @AppStorage(SmartSuggestions.enabledKey) private var smartSuggestionsEnabled = SmartSuggestions.enabledByDefault
    // Las sugerencias solo se ofrecen al añadir un gasto o al completar uno pendiente: al editar uno
    // completo, corregir una errata no debe cambiar nada más.
    private let offersSuggestions: Bool
    @State private var suggestionIndex: ExpenseSuggestionIndex?
    @State private var autofill: ExpenseAutofill
    @FocusState private var isTitleFocused: Bool

    // El gasto recurrente que creó este gasto, si sigue existiendo: como mucho uno.
    @Query private var sourceRecurringExpenses: [RecurringExpense]

    init(expense: Expense? = nil) {
        self.expenseToEdit = expense
        let paymentMethod = expense?.paymentMethod ?? .card
        _amount = State(initialValue: AmountInput(expense?.amount))
        _date = State(initialValue: expense?.date ?? .now)
        _title = State(initialValue: expense?.title ?? "")
        _paymentMethod = State(initialValue: paymentMethod)
        _category = State(initialValue: expense?.category)
        offersSuggestions = expense?.needsDetails ?? true
        _autofill = State(initialValue: ExpenseAutofill(initialPaymentMethod: paymentMethod))
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

    // Mientras se escribe el título, los gastos anteriores que coinciden.
    private var visibleSuggestions: [ExpenseSuggestion] {
        guard isTitleFocused, let suggestionIndex else { return [] }
        return suggestionIndex.suggestions(matching: title)
    }

    private var predictedFieldsNote: LocalizedStringKey? {
        switch (autofill.isPredicted(category), autofill.isPredicted(paymentMethod)) {
        case (true, true): "Categoría y método de pago sugeridos según tus gastos anteriores."
        case (true, false): "Categoría sugerida según tus gastos anteriores."
        case (false, true): "Método de pago sugerido según tus gastos anteriores."
        case (false, false): nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Título")
                        TextField("", text: $title)
                            .focused($isTitleFocused)
                    }
                    ForEach(visibleSuggestions) { suggestion in
                        ExpenseSuggestionRow(suggestion: suggestion) {
                            applySuggestion(suggestion)
                        }
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
                    VStack(alignment: .leading, spacing: 4) {
                        AmountDecimalsWarning(input: amount)
                        if let predictedFieldsNote {
                            Label(predictedFieldsNote, systemImage: "sparkles")
                        }
                    }
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
            .task {
                if offersSuggestions && smartSuggestionsEnabled {
                    suggestionIndex = ExpenseSuggestionIndex.load(context: modelContext)
                }
            }
            // Al dejar de escribir el título, se deducen la categoría y el método de pago.
            .task(id: title) {
                guard let suggestionIndex else { return }
                do {
                    try await Task.sleep(for: .milliseconds(600))
                } catch {
                    return
                }
                autofill.apply(suggestionIndex.prediction(for: title), forTitle: title, category: &category, paymentMethod: &paymentMethod)
            }
        }
    }

    private func applySuggestion(_ suggestion: ExpenseSuggestion) {
        autofill.apply(suggestion, title: &title, amount: &amount, category: &category, paymentMethod: &paymentMethod)
        isTitleFocused = false
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
