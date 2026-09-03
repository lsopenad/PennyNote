import AppIntents
import SwiftData
import Foundation
import os

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
        let categories: [ExpenseCategory]
        do {
            categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        } catch {
            Log.data.error("Fallo al buscar categorías al registrar gasto desde Atajos: \(error.localizedDescription)")
            categories = []
        }
        let matchedCategory = categories.first { $0.id == category.id }

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
