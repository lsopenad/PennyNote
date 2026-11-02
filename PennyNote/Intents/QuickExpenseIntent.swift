import AppIntents
import Foundation
#if !WIDGET_EXTENSION
import SwiftData
#endif

// Gasto rápido: pide solo la cantidad y lo guarda sin abrir la app, sin categoría ni título (queda
// pendiente de completar, ver Expense.needsDetails). Lo usan el control de la pantalla de bloqueo y Siri.
//
// Está en los dos targets porque el control necesita el tipo, pero el widget no puede guardar: no ve la
// sesión ni la sincronización. LiveActivityIntent hace que el sistema lo ejecute en el proceso de la
// app aunque lo lance el control; con AppIntent a secas se ejecutaría en la extensión.
struct QuickExpenseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Gasto rápido"
    static var description = IntentDescription("Registra solo la cantidad. Los detalles se completan luego en PennyNote.")
    // Desde la pantalla de bloqueo pide desbloquear antes: nadie puede meter gastos con el móvil ajeno.
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    // Opcional para pedirla siempre en perform(): el control no rellena los parámetros que faltan.
    @Parameter(title: "Cantidad")
    var amount: Double?

    static var parameterSummary: some ParameterSummary {
        Summary("Gasto rápido de \(\.$amount)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: try await logExpense())
    }

    @MainActor
    private func logExpense() async throws -> IntentDialog {
        #if WIDGET_EXTENSION
        Log.widget.fault("QuickExpenseIntent se ha ejecutado en la extensión del widget en vez de en la app")
        return IntentDialog("No se ha podido guardar el gasto.")
        #else
        try ExpenseIntentValidation.requireActiveSession()

        let requestedAmount: Double
        if let amount {
            requestedAmount = amount
        } else {
            requestedAmount = try await $amount.requestValue("¿Cuánto has gastado?")
        }
        let validAmount = try ExpenseIntentValidation.amount(from: requestedAmount)

        ExpenseRepository.addExpense(
            amount: validAmount,
            date: .now,
            category: nil,
            context: ModelContext(SharedModelContainer.container)
        )

        let formattedAmount = DisplayFormat.currency(validAmount, in: CurrencySettings.shared.currency)
        return IntentDialog("Gasto de \(formattedAmount) guardado")
        #endif
    }
}
