import SwiftUI
import SwiftData

struct AddEditExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
        return amount > 0
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
                        TextField("0,00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("€")
                            .foregroundStyle(.secondary)
                    }
                    CategoryPickerView(selection: $category)
                    Picker("Método de pago", selection: $paymentMethod) {
                        ForEach(PaymentMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle(expenseToEdit == nil ? "Añadir gasto" : "Editar gasto")
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
