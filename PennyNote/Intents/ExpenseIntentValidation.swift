import Foundation

// Comprobaciones comunes a los intents que registran gastos (LogExpenseIntent y QuickExpenseIntent).
@MainActor
enum ExpenseIntentValidation {
    // Sin sesión (o con la sesión caducada) el gasto no tendría cuenta segura a la que subirse: si
    // luego entrara otra cuenta, se borraría con el resto de datos locales.
    static func requireActiveSession() throws {
        guard SyncStateStore.standard.hasActiveSession else {
            throw LogExpenseError.signedOut
        }
    }

    // Con el almacén de respaldo en memoria, el gasto se perdería al terminar el atajo.
    static func requireUsableStore() throws {
        guard !SharedModelContainer.isInMemoryFallback else {
            throw LogExpenseError.storeUnavailable
        }
    }

    static func amount(from value: Double) throws -> Decimal {
        // Nunca Decimal(double) directo: se convierte vía texto para evitar artefactos binarios.
        let amount = Decimal(string: String(value)) ?? Decimal(value)
        guard ExpenseLimits.isValidAmount(amount) else {
            throw LogExpenseError.invalidAmount
        }
        guard ExpenseLimits.hasValidFractionDigits(amount, for: CurrencySettings.shared.currency) else {
            throw LogExpenseError.tooManyDecimals
        }
        return amount
    }
}
