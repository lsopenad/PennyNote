import SwiftUI

// Fila de la lista de gastos recurrentes: qué, cada cuánto y cuándo toca el próximo.
struct RecurringExpenseRow: View {
    @Environment(\.currency) private var currency

    let recurringExpense: RecurringExpense

    private var name: String {
        recurringExpense.title.isEmpty ? recurringExpense.category.displayName : recurringExpense.title
    }

    private var schedule: String {
        let frequency = String(localized: recurringExpense.frequency.title)
        guard !recurringExpense.isPaused else {
            return String(localized: "\(frequency) · En pausa")
        }
        let next = recurringExpense.nextDate.formatted(.dateTime.day().month())
        return String(localized: "\(frequency) · Próximo: \(next)")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recurringExpense.category.displaySymbolName)
                .font(.title3)
                .foregroundStyle(recurringExpense.category.displayColor)
                .frame(width: 32, height: 32)
                .background(recurringExpense.category.displayColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                Text(verbatim: schedule)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(DisplayFormat.currency(recurringExpense.amount, in: currency))
                .font(.body.monospacedDigit())
                .foregroundStyle(recurringExpense.isPaused ? .secondary : .primary)
        }
        .padding(.vertical, 4)
    }
}
