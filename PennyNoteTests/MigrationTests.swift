import Foundation
import SwiftData
import Testing
@testable import PennyNote

@MainActor
struct MigrationTests {
    @Test func v1PaymentMethodNamesBecomeCodes() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "MigrationTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")

        // Almacén creado por la 1.2.0.
        let expenseID = UUID()
        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = ModelContext(container)
            let category = SchemaV1.ExpenseCategory(name: "Comida", symbolName: "fork.knife", sortOrder: 0)
            context.insert(category)
            let expense = SchemaV1.Expense(id: expenseID, amount: 12, paymentMethod: .transfer)
            expense.category = category
            context.insert(expense)
            context.insert(SchemaV1.Expense(amount: 3, paymentMethod: .cash))
            try context.save()
        }

        let schema = Schema(versionedSchema: SchemaV4.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: PennyNoteMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let expenses = try ModelContext(container).fetch(FetchDescriptor<Expense>())

        #expect(Set(expenses.map(\.storedPaymentMethod)) == ["transfer", "cash"])
        let migrated = try #require(expenses.first { $0.id == expenseID })
        #expect(migrated.paymentMethod == .transfer)
        #expect(migrated.amount == 12)
        #expect(migrated.category?.name == "Comida")
    }

    @Test func v2StoreOpensWithRecurringExpenses() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "MigrationTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")

        // Almacén creado por la 1.5.0.
        let expenseID = UUID()
        do {
            let schema = Schema(versionedSchema: SchemaV2.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = ModelContext(container)
            let category = SchemaV2.ExpenseCategory(name: "Casa", symbolName: "house.fill", sortOrder: 0)
            context.insert(category)
            let expense = SchemaV2.Expense(id: expenseID, amount: 700, paymentMethod: .transfer)
            expense.category = category
            context.insert(expense)
            try context.save()
        }

        let schema = Schema(versionedSchema: SchemaV4.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: PennyNoteMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let context = ModelContext(container)
        let migrated = try #require(try context.fetch(FetchDescriptor<Expense>()).first)

        #expect(migrated.id == expenseID)
        #expect(migrated.paymentMethod == .transfer)
        #expect(migrated.category?.name == "Casa")
        #expect(migrated.recurringExpenseID == nil)
        context.insert(RecurringExpense(amount: 700, frequency: .monthly, startDate: .now, nextDate: .now))
        try context.save()
        #expect(try context.fetch(FetchDescriptor<RecurringExpense>()).count == 1)
    }

    // 1.10.0: symbolName pasa a ser el icono (sin perder el valor) y se quita el color.
    @Test func v3CategorySymbolBecomesItsIcon() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "MigrationTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")

        // Almacén creado por la 1.9.1.
        let categoryID = UUID()
        do {
            let schema = Schema(versionedSchema: SchemaV3.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = ModelContext(container)
            let category = SchemaV3.ExpenseCategory(id: categoryID, name: "Ocio", symbolName: "gamecontroller.fill", sortOrder: 2, colorName: "green")
            context.insert(category)
            let expense = SchemaV3.Expense(amount: 15, paymentMethod: .card)
            expense.category = category
            context.insert(expense)
            let recurringExpense = SchemaV3.RecurringExpense(amount: 9.99, frequency: .monthly, startDate: .now)
            recurringExpense.category = category
            context.insert(recurringExpense)
            try context.save()
        }

        let schema = Schema(versionedSchema: SchemaV4.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: PennyNoteMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let context = ModelContext(container)
        let migrated = try #require(try context.fetch(FetchDescriptor<ExpenseCategory>()).first)

        #expect(migrated.id == categoryID)
        #expect(migrated.name == "Ocio")
        #expect(migrated.icon == .symbol("gamecontroller.fill"))
        #expect(migrated.sortOrder == 2)
        #expect(migrated.expenses.count == 1)
        #expect(migrated.recurringExpenses.count == 1)
    }

    @Test func unknownStoredPaymentMethodReadsAsOther() {
        let expense = Expense(amount: 1, paymentMethod: .card)
        #expect(PaymentMethod(legacyName: "Tarjeta") == .card)
        #expect(PaymentMethod(rawValue: "bizum") == nil)
        #expect(expense.paymentMethod == .card)
    }
}
