import SwiftUI
import SwiftData

struct AddEditExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let expenseToEdit: Expense?

    @State private var amountText: String
    @State private var date: Date
    @State private var note: String
    @State private var category: ExpenseCategory?

    init(expense: Expense? = nil) {
        self.expenseToEdit = expense
        _amountText = State(initialValue: expense.map { "\($0.amount)" } ?? "")
        _date = State(initialValue: expense?.date ?? .now)
        _note = State(initialValue: expense?.note ?? "")
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
                    TextField("Cantidad", text: $amountText)
                        .keyboardType(.decimalPad)
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    CategoryPickerView(selection: $category)
                }
                Section {
                    TextField("Nota", text: $note)
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
                note: note,
                category: category,
                context: modelContext
            )
        } else {
            ExpenseRepository.addExpense(amount: amount, date: date, note: note, category: category, context: modelContext)
        }

        dismiss()
    }
}
