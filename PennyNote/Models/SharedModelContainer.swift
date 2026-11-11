import Foundation
import SwiftData

// Contenedor único compartido por la app y LogExpenseIntent (Atajos), para que
// todos lean/escriban exactamente el mismo almacén SwiftData. Vive en el App Group para que
// cualquier otro proceso que se añada (p. ej. una extensión) apunte al mismo store.
enum SharedModelContainer {
    static var container: ModelContainer { opened.container }

    // Verdadero si no se pudo abrir el almacén en disco y la app trabaja sobre uno vacío en memoria: no se
    // sincroniza, no se publica el widget y no se guardan gastos hasta el próximo arranque.
    static var isInMemoryFallback: Bool { opened.isInMemoryFallback }

    private static let opened: (container: ModelContainer, isInMemoryFallback: Bool) = {
        let schema = Schema(versionedSchema: SchemaV5.self)
        let groupContainer: ModelConfiguration.GroupContainer
        if AppGroupConstants.isAvailable {
            groupContainer = .identifier(AppGroupConstants.identifier)
        } else {
            // Sin el grupo, el almacén propio de la app: el widget y Atajos no verán los gastos, pero
            // la app abre. SwiftData no lanza un error con un grupo ajeno, la cierra.
            Log.data.fault("La firma no incluye el App Group \(AppGroupConstants.identifier, privacy: .public), se usa el almacén propio de la app")
            groupContainer = .none
        }
        #if DEBUG
        if DebugSeed.isActive {
            return (DebugSeed.makeContainer(schema: schema, groupContainer: groupContainer), false)
        }
        #endif
        let configuration = ModelConfiguration(schema: schema, groupContainer: groupContainer)
        do {
            return (try ModelContainer(for: schema, migrationPlan: PennyNoteMigrationPlan.self, configurations: [configuration]), false)
        } catch {
            Log.data.fault("Fallo al crear el ModelContainer compartido, se usa uno en memoria como último recurso: \(error.localizedDescription)")
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return (try ModelContainer(for: schema, configurations: [fallbackConfiguration]), true)
            } catch {
                fatalError("No se pudo crear ni siquiera el ModelContainer en memoria: \(error)")
            }
        }
    }()
}
