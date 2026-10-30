import Foundation

// Lo que se exporta de un gasto, con los textos ya resueltos. El fichero se genera cuando la hoja
// de compartir lo pide, fuera del hilo principal, y los modelos de SwiftData no pueden salir de él.
struct ExportRow: Sendable, Equatable {
    let date: Date
    let title: String
    let categoryName: String
    let paymentMethodName: String
    let amount: Decimal

    // Del más antiguo al más reciente, con los nombres de los métodos de pago traducidos una vez.
    static func rows(for expenses: [Expense]) -> [ExportRow] {
        let paymentMethodNames = Dictionary(
            uniqueKeysWithValues: PaymentMethod.allCases.map { ($0, String(localized: $0.title)) }
        )
        return expenses
            .filter { !$0.isSoftDeleted }
            .sorted { $0.date < $1.date }
            .map { expense in
                ExportRow(
                    date: expense.date,
                    title: expense.title,
                    categoryName: expense.category.displayName,
                    paymentMethodName: paymentMethodNames[expense.paymentMethod] ?? "",
                    amount: expense.amount
                )
            }
    }
}
