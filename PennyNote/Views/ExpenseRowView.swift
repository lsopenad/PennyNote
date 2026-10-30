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
            // El color de la categoría, el mismo que en Categorías y Estadísticas.
            Image(systemName: expense.category.displaySymbolName)
                .font(.title3)
                .foregroundStyle(expense.category.displayColor)
                .frame(width: 32, height: 32)
                .background(expense.category.displayColor.opacity(0.12), in: Circle())

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
