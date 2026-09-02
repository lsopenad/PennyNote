import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense

    private var amountLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: expense.amount as NSDecimalNumber) ?? "\(expense.amount) €"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category?.symbolName ?? "questionmark.circle")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)
                .background(.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.note.isEmpty ? (expense.category?.name ?? "Sin categoría") : expense.note)
                    .font(.body)
                if !expense.note.isEmpty {
                    Text(expense.category?.name ?? "Sin categoría")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(amountLabel)
                .font(.body.monospacedDigit())
        }
        .padding(.vertical, 4)
    }
}
