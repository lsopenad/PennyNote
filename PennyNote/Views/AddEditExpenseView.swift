import SwiftUI
import SwiftData

struct AddEditExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currency) private var currency

    private let expenseToEdit: Expense?

    @State private var amountText: String
    @State private var date: Date
    @State private var title: String
    @State private var paymentMethod: PaymentMethod
    @State private var category: ExpenseCategory?

    init(expense: Expense? = nil) {
        self.expenseToEdit = expense
        _amountText = State(initialValue: expense.map { "\($0.amount)" } ?? "")
        _date = State(initialValue: expense?.date ?? .now)
        _title = State(initialValue: expense?.title ?? "")
        _paymentMethod = State(initialValue: expense?.paymentMethod ?? .card)
        _category = State(initialValue: expense?.category)
    }

    private var parsedAmount: Decimal? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    private var canSave: Bool {
        guard let amount = parsedAmount else { return false }
        return ExpenseLimits.isValidAmount(amount) && ExpenseLimits.hasValidFractionDigits(amount, for: currency)
    }

    // Más decimales de los que usa la moneda, p. ej. céntimos en yenes o un gasto antiguo tras cambiarla.
    private var hasTooManyDecimals: Bool {
        parsedAmount.map { !ExpenseLimits.hasValidFractionDigits($0, for: currency) } ?? false
    }

    private var amountPlaceholder: String {
        Decimal.zero.formatted(.number.precision(.fractionLength(currency.fractionDigits)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Título")
                        TextField("", text: $title)
                    }
                    HStack {
                        Text("Cantidad")
                        Spacer()
                        TextField(amountPlaceholder, text: $amountText)
                            .keyboardType(currency.fractionDigits == 0 ? .numberPad : .decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(currency.symbol)
                            .foregroundStyle(.secondary)
                    }
                    CategoryPickerView(selection: $category)
                    Picker("Método de pago", selection: $paymentMethod) {
                        ForEach(PaymentMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                } footer: {
                    if hasTooManyDecimals {
                        if currency.fractionDigits == 0 {
                            Text("Tu moneda no usa decimales.")
                        } else {
                            Text("Tu moneda usa como máximo \(currency.fractionDigits) decimales.")
                        }
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
        guard let amount = parsedAmount else { return }

        if let expense = expenseToEdit {
            ExpenseRepository.updateExpense(
                expense,
                amount: amount,
                date: date,
                title: title,
                paymentMethod: paymentMethod,
                category: category,
                context: modelContext
            )
        } else {
            ExpenseRepository.addExpense(
                amount: amount,
                date: date,
                title: title,
                paymentMethod: paymentMethod,
                category: category,
                context: modelContext
            )
        }

        dismiss()
    }
}
