import Foundation
import SwiftData

// Esquema actual: los modelos de la app.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Expense.self, ExpenseCategory.self]
    }
}

// Migraciones del almacén local. Un cambio de modelo que no sea ligero (añadir un campo opcional o
// con valor por defecto) necesita un esquema nuevo y su etapa aquí.
enum PennyNoteMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
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
            let expenses = try context.fetch(FetchDescriptor<Expense>())
            for expense in expenses {
                expense.paymentMethod = migratedPaymentMethods[expense.id] ?? .other
            }
            try context.save()
            Log.data.notice("Migrados los métodos de pago de \(expenses.count) gastos a códigos")
            migratedPaymentMethods = [:]
        }
    )

    // Lo que lee willMigrate para didMigrate. Las dos se ejecutan una tras otra, de forma síncrona,
    // dentro de la creación del ModelContainer: no hay accesos concurrentes.
    nonisolated(unsafe) private static var migratedPaymentMethods: [UUID: PaymentMethod] = [:]
}
