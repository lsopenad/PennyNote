import SwiftUI

struct ExpenseRowView: View {
    @Environment(\.currency) private var currency

    let expense: Expense

    private var categoryName: String {
        expense.category.displayName
    }

    // Sin título, la categoría ocupa su lugar y no se repite como subtítulo.
    private var hasTitle: Bool {
        !expense.title.isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconBadge(icon: expense.category.displayIcon)

            VStack(alignment: .leading, spacing: 2) {
                Text(hasTitle ? expense.title : categoryName)
                    .font(.body)
                if hasTitle {
                    Text(categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if expense.needsDetails {
                    Label("Por completar", systemImage: Expense.needsDetailsSymbolName)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if expense.recurringExpenseID != nil {
                Image(systemName: "repeat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Recurrente"))
            }

            Text(DisplayFormat.currency(expense.amount, in: currency))
                .font(.body.monospacedDigit())
        }
        .padding(.vertical, 4)
    }
}
