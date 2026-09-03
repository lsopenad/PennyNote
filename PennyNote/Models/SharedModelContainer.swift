import Foundation
import SwiftData
import os

// Contenedor único compartido por la app y por LogExpenseIntent (Atajos), para que ambos
// lean/escriban exactamente el mismo almacén SwiftData. Debe vivir en el App Group: si no,
// cada proceso (app vs. extensión de Atajos) puede acabar leyendo/escribiendo un store distinto.
enum SharedModelContainer {
    static let container: ModelContainer = {
        let schema = Schema([Expense.self, ExpenseCategory.self])
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppGroupConstants.identifier)
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            Log.data.fault("Fallo al crear el ModelContainer compartido, se usa uno en memoria como último recurso: \(error.localizedDescription)")
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallbackConfiguration])
        }
    }()
}
