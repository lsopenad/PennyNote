import SwiftUI

// Importe tecleado en un formulario, con las comprobaciones de la moneda y del servidor. Lo comparten
// el formulario de gasto y el de gasto recurrente.
struct AmountInput {
    var text: String

    init(_ amount: Decimal? = nil) {
        text = amount.map { "\($0)" } ?? ""
    }

    var value: Decimal? {
        Decimal(string: text.replacingOccurrences(of: ",", with: "."))
    }

    func isValid(for currency: AppCurrency) -> Bool {
        guard let value else { return false }
        return ExpenseLimits.isValidAmount(value) && ExpenseLimits.hasValidFractionDigits(value, for: currency)
    }

    // Más decimales de los que usa la moneda, p. ej. céntimos en yenes o un gasto antiguo tras cambiarla.
    func hasTooManyDecimals(for currency: AppCurrency) -> Bool {
        value.map { !ExpenseLimits.hasValidFractionDigits($0, for: currency) } ?? false
    }
}

// Fila «Cantidad» con el símbolo de la moneda.
struct AmountField: View {
    @Environment(\.currency) private var currency
    @Binding var input: AmountInput

    private var placeholder: String {
        Decimal.zero.formatted(.number.precision(.fractionLength(currency.fractionDigits)))
    }

    var body: some View {
        HStack {
            Text("Cantidad")
            Spacer()
            TextField(placeholder, text: $input.text)
                .keyboardType(currency.fractionDigits == 0 ? .numberPad : .decimalPad)
                .multilineTextAlignment(.trailing)
            Text(currency.symbol)
                .foregroundStyle(.secondary)
        }
    }
}

// Pie de sección que avisa de que sobran decimales.
struct AmountDecimalsWarning: View {
    @Environment(\.currency) private var currency
    let input: AmountInput

    var body: some View {
        if input.hasTooManyDecimals(for: currency) {
            if currency.fractionDigits == 0 {
                Text("Tu moneda no usa decimales.")
            } else {
                Text("Tu moneda usa como máximo \(currency.fractionDigits) decimales.")
            }
        }
    }
}
