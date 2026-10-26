import AppIntents
import SwiftData
import Foundation

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar gasto"
    static var description = IntentDescription("Añade un gasto a PennyNote.")

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
        // Sin sesión no hay datos locales: un gasto apuntado así no tendría cuenta a la que subirse.
        guard SyncStateStore.standard.ownerUserID != nil else {
            throw LogExpenseError.signedOut
        }

        let context = ModelContext(SharedModelContainer.container)
        let matchedCategory = context.category(
            withID: category.id,
            failureMessage: "Fallo al buscar la categoría al registrar gasto desde Atajos"
        )

        // Nunca Decimal(double) directo: se convierte vía texto para evitar artefactos binarios.
        let amountDecimal = Decimal(string: String(amount)) ?? Decimal(amount)
        guard ExpenseLimits.isValidAmount(amountDecimal) else {
            throw LogExpenseError.invalidAmount
        }

        ExpenseRepository.addExpense(
            amount: amountDecimal,
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
    case signedOut

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidAmount: "La cantidad tiene que ser mayor que 0."
        case .signedOut: "Inicia sesión en PennyNote para registrar gastos."
        }
    }
}
