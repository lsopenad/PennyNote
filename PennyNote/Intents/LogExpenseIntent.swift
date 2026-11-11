import AppIntents
import SwiftData
import Foundation

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar gasto"
    static var description = IntentDescription("Añade un gasto a PennyNote.")
    // Desde la pantalla de bloqueo pide desbloquear antes: nadie puede meter gastos ni ver las
    // categorías con el móvil ajeno.
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Cantidad")
    var amount: Double

    @Parameter(title: "Título")
    var expenseTitle: String

    // Sin valor por defecto a propósito: es lo que permite que Atajos ofrezca "Preguntar cada vez".
    @Parameter(title: "Categoría")
    var category: CategoryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Registrar gasto de \(\.$amount) en \(\.$category)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try ExpenseIntentValidation.requireActiveSession()
        try ExpenseIntentValidation.requireUsableStore()

        let context = ModelContext(SharedModelContainer.container)
        let matchedCategory = context.category(
            withID: category.id,
            failureMessage: "Fallo al buscar la categoría al registrar gasto desde Atajos"
        )

        let validAmount = try ExpenseIntentValidation.amount(from: amount)

        ExpenseRepository.addExpense(
            amount: validAmount,
            date: .now,
            title: expenseTitle,
            category: matchedCategory,
            context: context
        )

        return .result()
    }
}

enum LogExpenseError: Error, CustomLocalizedStringResourceConvertible {
    case invalidAmount
    case tooManyDecimals
    case signedOut
    case storeUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidAmount: "La cantidad tiene que ser mayor que 0."
        case .tooManyDecimals: "La cantidad tiene más decimales de los que usa la moneda de tu cuenta."
        case .signedOut: "Inicia sesión en PennyNote para registrar gastos."
        case .storeUnavailable: "No se han podido abrir los datos de PennyNote. Abre la app y vuelve a intentarlo."
        }
    }
}
