import Foundation
import SwiftData
import os

// Contenedor único compartido por la app, el SyncEngine y LogExpenseIntent (Atajos), para que
// todos lean/escriban exactamente el mismo almacén SwiftData. Vive en el App Group para que
// cualquier otro proceso que se añada (p. ej. una extensión) apunte al mismo store.
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
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                fatalError("No se pudo crear ni siquiera el ModelContainer en memoria: \(error)")
            }
        }
    }()
}
