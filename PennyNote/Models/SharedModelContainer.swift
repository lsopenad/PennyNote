import Foundation
import SwiftData

// Contenedor único compartido por la app y por LogExpenseIntent (Atajos), para que ambos
// lean/escriban exactamente el mismo almacén SwiftData.
enum SharedModelContainer {
    static let container: ModelContainer = {
        let schema = Schema([Expense.self, ExpenseCategory.self])
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()
}
