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
        let context = ModelContext(SharedModelContainer.container)
        let categoryID = category.id
        var descriptor = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.id == categoryID })
        descriptor.fetchLimit = 1
        let matchedCategory = context
            .fetchOrEmpty(descriptor, failureMessage: "Fallo al buscar la categoría al registrar gasto desde Atajos")
            .first

        // Nunca Decimal(double) directo: se convierte vía texto para evitar artefactos binarios.
        let amountDecimal = Decimal(string: String(amount)) ?? Decimal(amount)

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
