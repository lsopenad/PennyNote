import Foundation
import SwiftData
import Testing
@testable import PennyNote

@MainActor
struct SyncEngineTests {
    private let context: ModelContext
    private let state: SyncStateStore
    private let currency: CurrencySettings
    private let remote = FakeSyncRemote()
    private let userID = UUID()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, RecurringExpense.self, configurations: configuration)
        context = ModelContext(container)
        state = SyncStateStore(defaults: try #require(UserDefaults(suiteName: "SyncEngineTests.\(UUID())")))
        currency = CurrencySettings(defaults: try #require(UserDefaults(suiteName: "SyncEngineTests.currency.\(UUID())")))
    }

    private var engine: SyncEngine {
        SyncEngine(context: context, remote: remote, state: state, currency: currency)
    }

    // MARK: - Primer login

    @Test func newAccountGetsDefaultCategoriesUploaded() async throws {
        try engine.prepareLocalData(for: userID)
        try await engine.sync()

        #expect(state.ownerUserID == userID)
        #expect(try fetchCategories().count == SeedDataService.defaultCategories.count)
        #expect(remote.categories.count == SeedDataService.defaultCategories.count)
    }

    @Test func existingAccountDoesNotGetDefaultCategories() async throws {
        let remoteCategory = remote.add(category: "Viajes")
        try engine.prepareLocalData(for: userID)
        try await engine.sync()

        #expect(try fetchCategories().map(\.id) == [remoteCategory.id])
    }

    @Test func loginWithAnotherAccountWipesLeftoverData() async throws {
        state.ownerUserID = UUID()
        context.insert(Expense(amount: 9))
        try context.save()

        try engine.prepareLocalData(for: userID)

        #expect(try fetchExpenses().isEmpty)
        #expect(state.ownerUserID == userID)
    }

    // MARK: - Last-write-wins

    @Test func pullAppliesRemoteChangesAndDeletions() async throws {
        let synced = try await signedInWithSyncedExpense()
        let deletedLater = Expense(amount: 1)
        context.insert(deletedLater)
        try await engine.sync()

        remote.edit(expense: synced.id) { $0.amount = 42; $0.title = "Cambiado fuera" }
        remote.edit(expense: deletedLater.id) { $0.isDeleted = true }
        try await engine.sync()

        let expenses = try fetchExpenses()
        #expect(expenses.map(\.id) == [synced.id])
        #expect(expenses.first?.amount == 42)
        #expect(expenses.first?.title == "Cambiado fuera")
        #expect(expenses.first?.syncStatus == .synced)
    }

    @Test func newerLocalChangeWinsOverOlderRemoteChange() async throws {
        let expense = try await signedInWithSyncedExpense()
        remote.edit(expense: expense.id, updatedAt: .now) { $0.amount = 42 }
        expense.amount = 7
        expense.markPendingSync()
        expense.localLastModified = .now.addingTimeInterval(60)

        try await engine.sync()

        #expect(expense.amount == 7)
        #expect(remote.expenses[expense.id]?.amount == 7)
    }

    @Test func newerRemoteChangeWinsOverOlderLocalChange() async throws {
        let expense = try await signedInWithSyncedExpense()
        expense.amount = 7
        expense.markPendingSync()
        remote.edit(expense: expense.id, updatedAt: .now.addingTimeInterval(60)) { $0.amount = 42 }

        try await engine.sync()

        #expect(expense.amount == 42)
        #expect(expense.syncStatus == .synced)
        #expect(remote.expenses[expense.id]?.amount == 42)
    }

    @Test func changeMadeWhileUploadingStaysPending() async throws {
        let expense = try await signedInWithSyncedExpense()
        expense.amount = 7
        expense.markPendingSync()
        remote.onUpsertExpenses = {
            expense.amount = 8
            expense.markPendingSync()
        }

        let remainingChanges = try await engine.sync()

        #expect(expense.syncStatus == .pending)
        #expect(remainingChanges == 1)
        #expect(SyncEngine.pendingChangeCount(context: context, state: state, currency: currency) == 1)
    }

    // MARK: - Borrados

    @Test func uploadedExpenseDeletionIsRemovedLocally() async throws {
        let expense = try await signedInWithSyncedExpense()
        expense.isSoftDeleted = true
        expense.markPendingSync()

        try await engine.sync()

        #expect(remote.expenses[expense.id]?.isDeleted == true)
        #expect(try fetchExpenses().isEmpty)
    }

    @Test func deletedCategoryIsUploadedAndNotRevivedByRemoteChanges() async throws {
        try engine.prepareLocalData(for: userID)
        try await engine.sync()
        let category = try #require(try fetchCategories().first)
        let categoryID = category.id
        remote.edit(category: categoryID) { $0.colorName = CategoryColor.red.rawValue }

        // Como ExpenseRepository.deleteCategory: el borrado es posterior al cambio remoto.
        category.localLastModified = .now
        state.addCategoryTombstone(RemoteCategory(category, isDeleted: true))
        context.delete(category)
        try await engine.sync()

        #expect(remote.categories[categoryID]?.isDeleted == true)
        #expect(state.categoryTombstones.isEmpty)
        #expect(try fetchCategories().contains { $0.id == categoryID } == false)
    }

    @Test func wipeRemovesAllLocalDataAndSyncState() throws {
        context.insert(Expense(amount: 1))
        context.insert(ExpenseCategory(name: "Comida", symbolName: "fork.knife", sortOrder: 0))
        state.ownerUserID = userID
        state.expensesCursor = .now
        state.hasActiveSession = true

        currency.choose(.jpy)

        try SyncEngine.wipeLocalData(context: context, state: state, currency: currency)

        #expect(try fetchExpenses().isEmpty)
        #expect(try fetchCategories().isEmpty)
        #expect(state.ownerUserID == nil)
        #expect(state.expensesCursor == nil)
        #expect(state.hasActiveSession == false)
        #expect(currency.currency == .regionDefault())
        #expect(currency.pendingRow == nil)
    }

    // MARK: - Moneda

    @Test func newAccountIsAskedForCurrencyWithRegionDefault() async throws {
        try engine.prepareLocalData(for: userID)
        try await engine.sync()

        #expect(currency.needsChoice)
        #expect(currency.currency == .regionDefault())
        #expect(remote.userSettings == nil)
    }

    @Test func accountWithExpensesButNoCurrencyIsSuggestedEuro() async throws {
        remote.add(expense: 12)
        try engine.prepareLocalData(for: userID)
        try await engine.sync()

        #expect(currency.needsChoice)
        #expect(currency.currency == .eur)
    }

    @Test func chosenCurrencyIsUploadedAndNotAskedAgain() async throws {
        try engine.prepareLocalData(for: userID)
        try await engine.sync()

        currency.choose(.jpy)
        let remaining = try await engine.sync()

        #expect(remote.userSettings?.currency == "JPY")
        #expect(currency.needsChoice == false)
        #expect(currency.pendingRow == nil)
        #expect(remaining == 0)
    }

    @Test func remoteCurrencyIsAppliedWithoutAsking() async throws {
        remote.setUserSettings(currency: "GBP", updatedAt: .now)
        try engine.prepareLocalData(for: userID)
        try await engine.sync()

        #expect(currency.currency == .gbp)
        #expect(currency.needsChoice == false)
    }

    @Test func newerLocalCurrencyWinsOverOlderRemote() async throws {
        remote.setUserSettings(currency: "GBP", updatedAt: .now.addingTimeInterval(-60))
        try engine.prepareLocalData(for: userID)
        currency.choose(.usd)
        try await engine.sync()

        #expect(currency.currency == .usd)
        #expect(remote.userSettings?.currency == "USD")
    }

    @Test func newerRemoteCurrencyWinsOverOlderLocal() async throws {
        try engine.prepareLocalData(for: userID)
        currency.choose(.usd)
        remote.setUserSettings(currency: "GBP", updatedAt: .now.addingTimeInterval(60))
        try await engine.sync()

        #expect(currency.currency == .gbp)
        #expect(currency.pendingRow == nil)
        #expect(remote.userSettings?.currency == "GBP")
    }

    @Test func pendingCurrencyCountsAsUnsyncedChange() {
        currency.choose(.chf)

        #expect(SyncEngine.pendingChangeCount(context: context, state: state, currency: currency) == 1)
    }

    // MARK: - Formato

    @Test func remoteExpenseKeepsDecimalPrecisionAndEncodesNullCategory() throws {
        let expense = RemoteExpense(
            id: UUID(),
            amount: Decimal(string: "0.1")!,
            date: .now,
            title: "",
            paymentMethod: "cash",
            categoryID: nil,
            isDeleted: false,
            createdAt: .now,
            updatedAt: .now
        )
        let json = try #require(String(data: try JSONEncoder().encode(expense), encoding: .utf8))
        #expect(json.contains(#""amount":"0.1""#))
        #expect(json.contains(#""category_id":null"#))
        #expect(!json.contains("server_updated_at"))

        let decoded = try JSONDecoder().decode(RemoteExpense.self, from: Data(json.utf8))
        #expect(decoded.amount == Decimal(string: "0.1"))
    }

    @Test func paymentMethodServerCodesRoundTrip() {
        for method in PaymentMethod.allCases {
            #expect(PaymentMethod(serverCode: method.serverCode) == method)
        }
    }

    // MARK: - Gastos recurrentes

    @Test func recurringExpenseAndItsExpensesAreUploaded() async throws {
        try engine.prepareLocalData(for: userID)
        let start = try #require(Calendar.current.date(byAdding: .month, value: -1, to: .now))
        let template = RecurringExpense(amount: 5, title: "Gimnasio", frequency: .monthly, startDate: start, nextDate: start)
        context.insert(template)

        try await engine.sync()

        let uploaded = try #require(remote.recurringExpenses[template.id])
        #expect(uploaded.title == "Gimnasio")
        #expect(uploaded.frequency == "monthly")
        #expect(uploaded.nextDate == template.nextDate)
        #expect(template.syncStatus == .synced)
        let generated = remote.expenses.values.filter { $0.recurringExpenseID == template.id }
        #expect(generated.count == 2)
    }

    @Test func remoteRecurringExpenseIsDownloadedAndGenerates() async throws {
        let next = try #require(Calendar.current.date(byAdding: .day, value: -1, to: .now))
        let remoteTemplate = remote.add(recurringExpense: "Alquiler", next: next)
        try engine.prepareLocalData(for: userID)

        try await engine.sync()

        let template = try #require(try context.fetch(FetchDescriptor<RecurringExpense>()).first)
        #expect(template.id == remoteTemplate.id)
        #expect(template.frequency == .monthly)
        #expect(template.nextDate > .now)
        #expect(try fetchExpenses().filter { $0.recurringExpenseID == template.id }.count == 1)
        #expect(remote.recurringExpenses[template.id]?.nextDate == template.nextDate)
    }

    @Test func deletedRecurringExpenseIsUploadedAndRemovedLocally() async throws {
        try engine.prepareLocalData(for: userID)
        let next = try #require(Calendar.current.date(byAdding: .month, value: 1, to: .now))
        let template = RecurringExpense(amount: 5, frequency: .weekly, startDate: next, nextDate: next)
        context.insert(template)
        try await engine.sync()

        template.isSoftDeleted = true
        template.markPendingSync()
        try await engine.sync()

        #expect(remote.recurringExpenses[template.id]?.isDeleted == true)
        #expect(try context.fetch(FetchDescriptor<RecurringExpense>()).isEmpty)
    }

    @Test func regeneratingAnExpenseDeletedElsewhereDoesNotBringItBack() async throws {
        try engine.prepareLocalData(for: userID)
        let start = try #require(Calendar.current.date(byAdding: .day, value: -1, to: .now))
        let template = RecurringExpense(amount: 5, frequency: .monthly, startDate: start, nextDate: start)
        context.insert(template)
        try await engine.sync()
        let generatedID = try #require(remote.expenses.values.first { $0.recurringExpenseID == template.id }?.id)

        // Otro móvil lo borra; este aún tiene la plantilla sin avanzar y lo vuelve a crear.
        remote.edit(expense: generatedID) { $0.isDeleted = true }
        try context.delete(#require(try fetchExpenses().first { $0.id == generatedID }))
        template.nextDate = start
        try await engine.sync()

        #expect(remote.expenses[generatedID]?.isDeleted == true)
        #expect(try fetchExpenses().allSatisfy { $0.id != generatedID })
    }

    @Test func recurringExpenseRowRoundTripsThroughJSON() throws {
        let row = RemoteRecurringExpense(
            id: UUID(),
            amount: Decimal(string: "12.99")!,
            title: "Netflix",
            paymentMethod: "card",
            categoryID: nil,
            frequency: "yearly",
            startDate: Date(timeIntervalSinceReferenceDate: 800_000_000),
            nextDate: Date(timeIntervalSinceReferenceDate: 831_536_000),
            isPaused: true,
            isDeleted: false,
            createdAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            updatedAt: Date(timeIntervalSinceReferenceDate: 800_000_100)
        )

        let decoded = try JSONDecoder().decode(RemoteRecurringExpense.self, from: JSONEncoder().encode(row))

        #expect(decoded == row)
    }

    @Test func recurrenceFrequencyServerCodesRoundTrip() {
        for frequency in RecurrenceFrequency.allCases {
            #expect(RecurrenceFrequency(serverCode: frequency.serverCode) == frequency)
        }
    }

    // MARK: - Utilidades

    private func signedInWithSyncedExpense() async throws -> Expense {
        try engine.prepareLocalData(for: userID)
        let expense = Expense(amount: 10)
        context.insert(expense)
        try await engine.sync()
        #expect(expense.syncStatus == .synced)
        return expense
    }

    private func fetchExpenses() throws -> [Expense] {
        try context.fetch(FetchDescriptor<Expense>())
    }

    private func fetchCategories() throws -> [ExpenseCategory] {
        try context.fetch(FetchDescriptor<ExpenseCategory>())
    }
}

// Servidor en memoria con las mismas reglas que el esquema SQL: last-write-wins por updated_at y
// server_updated_at creciente en cada escritura.
@MainActor
private final class FakeSyncRemote: SyncRemote {
    private(set) var categories: [UUID: RemoteCategory] = [:]
    private(set) var expenses: [UUID: RemoteExpense] = [:]
    private(set) var recurringExpenses: [UUID: RemoteRecurringExpense] = [:]
    private(set) var userSettings: RemoteUserSettings?
    var onUpsertExpenses: (() -> Void)?
    private var clock = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func upsertCategories(_ rows: [RemoteCategory]) async throws {
        for row in rows where (categories[row.id]?.updatedAt ?? .distantPast) <= row.updatedAt {
            var stored = row
            stored.serverUpdatedAt = tick()
            categories[row.id] = stored
        }
    }

    func upsertExpenses(_ rows: [RemoteExpense]) async throws {
        for row in rows where (expenses[row.id]?.updatedAt ?? .distantPast) <= row.updatedAt {
            var stored = row
            stored.serverUpdatedAt = tick()
            expenses[row.id] = stored
        }
        onUpsertExpenses?()
        onUpsertExpenses = nil
    }

    func upsertRecurringExpenses(_ rows: [RemoteRecurringExpense]) async throws {
        for row in rows where (recurringExpenses[row.id]?.updatedAt ?? .distantPast) <= row.updatedAt {
            var stored = row
            stored.serverUpdatedAt = tick()
            recurringExpenses[row.id] = stored
        }
    }

    func fetchRecurringExpenses(changedSince since: Date?) async throws -> [RemoteRecurringExpense] {
        recurringExpenses.values.filter { since == nil || $0.serverUpdatedAt! > since! }
    }

    func fetchCategories(changedSince since: Date?) async throws -> [RemoteCategory] {
        categories.values.filter { since == nil || $0.serverUpdatedAt! > since! }
    }

    func fetchExpenses(changedSince since: Date?) async throws -> [RemoteExpense] {
        expenses.values.filter { since == nil || $0.serverUpdatedAt! > since! }
    }

    func fetchUserSettings() async throws -> RemoteUserSettings? {
        userSettings
    }

    func upsertUserSettings(_ settings: RemoteUserSettings) async throws {
        guard (userSettings?.updatedAt ?? .distantPast) <= settings.updatedAt else { return }
        var stored = settings
        stored.serverUpdatedAt = tick()
        userSettings = stored
    }

    // Simula la moneda elegida desde otro dispositivo.
    func setUserSettings(currency: String, updatedAt: Date) {
        userSettings = RemoteUserSettings(currency: currency, updatedAt: updatedAt, serverUpdatedAt: tick())
    }

    func add(expense amount: Decimal) {
        let expense = RemoteExpense(
            id: UUID(),
            amount: amount,
            date: .now,
            title: "",
            paymentMethod: "card",
            categoryID: nil,
            isDeleted: false,
            createdAt: .now,
            updatedAt: .now,
            serverUpdatedAt: tick()
        )
        expenses[expense.id] = expense
    }

    @discardableResult
    func add(category name: String) -> RemoteCategory {
        let category = RemoteCategory(
            id: UUID(),
            name: name,
            symbolName: "tag.fill",
            sortOrder: categories.count,
            colorName: nil,
            isDeleted: false,
            updatedAt: .now,
            serverUpdatedAt: tick()
        )
        categories[category.id] = category
        return category
    }

    // Un gasto recurrente mensual creado desde otro dispositivo.
    func add(recurringExpense title: String, next: Date) -> RemoteRecurringExpense {
        let row = RemoteRecurringExpense(
            id: UUID(),
            amount: 700,
            title: title,
            paymentMethod: "transfer",
            categoryID: nil,
            frequency: "monthly",
            startDate: next,
            nextDate: next,
            isPaused: false,
            isDeleted: false,
            createdAt: .now,
            updatedAt: .now,
            serverUpdatedAt: tick()
        )
        recurringExpenses[row.id] = row
        return row
    }

    // Simula un cambio hecho desde otro dispositivo.
    func edit(expense id: UUID, updatedAt: Date = .now, _ change: (inout RemoteExpense) -> Void) {
        guard var expense = expenses[id] else { return }
        change(&expense)
        expense.updatedAt = updatedAt
        expense.serverUpdatedAt = tick()
        expenses[id] = expense
    }

    func edit(category id: UUID, _ change: (inout RemoteCategory) -> Void) {
        guard var category = categories[id] else { return }
        change(&category)
        category.updatedAt = .now
        category.serverUpdatedAt = tick()
        categories[id] = category
    }

    // Avanza siempre, más que el margen con el que SyncEngine vuelve a pedir lo anterior al cursor.
    private func tick() -> Date {
        clock = clock.addingTimeInterval(SyncEngine.pullOverlap + 1)
        return clock
    }
}
