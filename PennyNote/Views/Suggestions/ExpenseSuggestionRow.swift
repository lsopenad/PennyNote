import SwiftUI

// Fila bajo el título del formulario con un gasto anterior que coincide con lo escrito. Al tocarla se
// rellena el gasto con sus datos.
struct ExpenseSuggestionRow: View {
    @Environment(\.currency) private var currency

    let suggestion: ExpenseSuggestion
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CategoryIconBadge(icon: suggestion.category.displayIcon, color: suggestion.category.displayColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.body)
                    Text(suggestion.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(DisplayFormat.currency(suggestion.amount, in: currency))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Rellena el gasto con estos datos"))
    }
}
