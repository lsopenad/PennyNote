import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense

    private var categoryName: String {
        expense.category?.name ?? ExpenseCategory.uncategorizedLabel
    }

    // Sin título, la categoría ocupa su lugar y no se repite como subtítulo.
    private var hasTitle: Bool {
        !expense.title.isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category?.symbolName ?? "questionmark.circle")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)
                .background(.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(hasTitle ? expense.title : categoryName)
                    .font(.body)
                if hasTitle {
                    Text(categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(DisplayFormat.currency(expense.amount))
                .font(.body.monospacedDigit())
        }
        .padding(.vertical, 4)
    }
}
