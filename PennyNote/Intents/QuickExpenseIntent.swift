import AppIntents
import SwiftData
import Foundation

// Gasto rápido: pide solo la cantidad y lo guarda sin abrir la app, sin categoría ni título (queda
// pendiente de completar, ver Expense.needsDetails). Pensado para Siri, el botón de acción y el control
// «Ejecutar atajo» de Atajos: desde un control propio de la app el sistema no deja pedir la cantidad
// (cancela la petición), por eso AddExpenseControl sigue abriendo la app.
struct QuickExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Gasto rápido"
    static var description = IntentDescription("Registra solo la cantidad. Los detalles se completan luego en PennyNote.")
    // Desde la pantalla de bloqueo pide desbloquear antes: nadie puede meter gastos con el móvil ajeno.
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    // Opcional para que Atajos la deje vacía y se pida al ejecutar, con el banner del sistema.
    @Parameter(title: "Cantidad")
    var amount: Double?

    static var parameterSummary: some ParameterSummary {
        Summary("Gasto rápido de \(\.$amount)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try ExpenseIntentValidation.requireActiveSession()
        try ExpenseIntentValidation.requireUsableStore()

        let requestedAmount: Double
        if let amount {
            requestedAmount = amount
        } else {
            requestedAmount = try await $amount.requestValue("¿Cuánto has gastado?")
        }
        let validAmount = try ExpenseIntentValidation.amount(from: requestedAmount)

        do {
            try ExpenseRepository.addExpense(
                amount: validAmount,
                date: .now,
                category: nil,
                context: ModelContext(SharedModelContainer.container)
            )
        } catch {
            throw LogExpenseError.saveFailed
        }

        let formattedAmount = DisplayFormat.currency(validAmount, in: CurrencySettings.shared.currency)
        return .result(dialog: "Gasto de \(formattedAmount) guardado")
    }
}
