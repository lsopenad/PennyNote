import Foundation
import SwiftData

// Esquema actual: los modelos de la app.
enum SchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Expense.self, ExpenseCategory.self, RecurringExpense.self]
    }
}

// Migraciones del almacén local. Cualquier cambio de modelo, aunque sea ligero, necesita congelar el
// esquema actual en su propio fichero (como SchemaV4), crear uno nuevo y añadir su etapa aquí: el
// esquema actual apunta a las clases vivas, y si cambian sin más deja de reconocer sus almacenes.
enum PennyNoteMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5]
    }

    // 1.3.0: el método de pago pasa de guardarse con su nombre en español ("Tarjeta", columna
    // paymentMethod) a su código ("card", columna storedPaymentMethod), el mismo que en el servidor,
    // para poder mostrarlo traducido. SwiftData no conserva los valores al renombrar una columna en una
    // etapa custom, así que se leen antes de migrar y se escriben después.
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            let expenses = try context.fetch(FetchDescriptor<SchemaV1.Expense>())
            migratedPaymentMethods = Dictionary(
                expenses.map { ($0.id, PaymentMethod(legacyName: $0.paymentMethod.rawValue) ?? .other) },
                uniquingKeysWith: { first, _ in first }
            )
        },
        didMigrate: { context in
            let expenses = try context.fetch(FetchDescriptor<SchemaV2.Expense>())
            for expense in expenses {
                expense.storedPaymentMethod = (migratedPaymentMethods[expense.id] ?? .other).rawValue
            }
            try context.save()
            Log.data.notice("Migrados los métodos de pago de \(expenses.count) gastos a códigos")
            migratedPaymentMethods = [:]
        }
    )

    // 1.6.0: gastos recurrentes. Solo se añaden la tabla de plantillas y el id de la plantilla en los
    // gastos, ambos opcionales, así que basta con la migración ligera.
    static let migrateV2toV3 = MigrationStage.lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self)

    // 1.10.0: el icono de la categoría puede ser un emoji además de un símbolo, así que symbolName pasa
    // a llamarse icon (con originalName, que la migración ligera respeta y conserva el valor), y las
    // categorías dejan de tener color.
    static let migrateV3toV4 = MigrationStage.lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self)

    // 1.12.0: las categorías vuelven a poder tener color, opcional (storedColor), así que basta con la
    // migración ligera. Las existentes quedan sin color.
    static let migrateV4toV5 = MigrationStage.lightweight(fromVersion: SchemaV4.self, toVersion: SchemaV5.self)

    // Lo que lee willMigrate para didMigrate. Las dos se ejecutan una tras otra, de forma síncrona,
    // dentro de la creación del ModelContainer: no hay accesos concurrentes.
    nonisolated(unsafe) private static var migratedPaymentMethods: [UUID: PaymentMethod] = [:]
}
