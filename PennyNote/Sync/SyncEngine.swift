import Foundation
import SwiftData

// Sincronización offline-first entre SwiftData y el servidor, con last-write-wins por fila: gana la
// versión con el localLastModified (updated_at en el servidor) más reciente.
//
// Una pasada de sync() primero baja lo cambiado en el servidor y después sube lo pendiente. Se
// trabaja con el contexto principal: los datos de una persona caben de sobra en memoria y así las
// vistas ven los cambios sin más.
@MainActor
final class SyncEngine {
    // Al bajar cambios se vuelve a pedir este margen anterior al cursor: dos escrituras casi
    // simultáneas pueden confirmarse en el servidor en distinto orden que su server_updated_at.
    static let pullOverlap: TimeInterval = 120
    static let pushBatchSize = 500

    private let context: ModelContext
    private let remote: SyncRemote
    private let state: SyncStateStore

    init(context: ModelContext, remote: SyncRemote, state: SyncStateStore) {
        self.context = context
        self.remote = remote
        self.state = state
    }

    // Deja los datos locales listos para el usuario que acaba de iniciar sesión.
    func prepareLocalData(for userID: UUID) throws {
        switch state.ownerUserID {
        case userID:
            return
        case nil:
            // Primer login tras instalar o tras cerrar sesión: no hay datos locales que conservar.
            state.ownerUserID = userID
        default:
            // Datos de otra cuenta que no se borraron al salir (sesión caducada): no se mezclan.
            Log.sync.notice("Los datos locales son de otra cuenta; se borran antes de sincronizar")
            try Self.wipeLocalData(context: context, state: state)
            state.ownerUserID = userID
        }
    }

    // Devuelve los cambios que siguen pendientes al terminar, calculados con lo que ya ha leído la
    // subida, para no volver a cargar todo el almacén solo para contarlos.
    @discardableResult
    func sync() async throws -> Int {
        try await pull()
        // Tras bajar todo, una cuenta sin categorías es una cuenta nueva: se le crean las de serie.
        SeedDataService.seedIfNeeded(context: context)
        try context.save()
        let remainingChanges = try await push()
        state.lastSyncDate = .now
        return remainingChanges
    }

    static func pendingChangeCount(context: ModelContext, state: SyncStateStore) -> Int {
        let categories = context.categories(failureMessage: "Fallo al contar categorías pendientes")
        let expenses = context.fetchOrEmpty(FetchDescriptor<Expense>(), failureMessage: "Fallo al contar gastos pendientes")
        return categories.filter { $0.syncStatus == .pending }.count
            + state.categoryTombstones.count
            + expenses.filter { $0.syncStatus == .pending }.count
    }

    // Borra todos los datos del móvil y el estado de la sincronización (al cerrar sesión o borrar la cuenta).
    static func wipeLocalData(context: ModelContext, state: SyncStateStore) throws {
        try context.fetch(FetchDescriptor<Expense>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<ExpenseCategory>()).forEach(context.delete)
        try context.save()
        state.reset()
        WidgetSnapshotStore.clear()
    }

    // MARK: - Bajar

    private func pull() async throws {
        let remoteCategories = try await remote.fetchCategories(changedSince: Self.pullStart(after: state.categoriesCursor))
        let remoteExpenses = try await remote.fetchExpenses(changedSince: Self.pullStart(after: state.expensesCursor))

        let categoriesByID = apply(remoteCategories)
        apply(remoteExpenses, categoriesByID: categoriesByID)
        // Primero se guarda y luego se avanza el cursor: si el guardado falla, la próxima vez se piden otra vez.
        try context.save()

        state.categoriesCursor = Self.latest(state.categoriesCursor, remoteCategories.compactMap(\.serverUpdatedAt))
        state.expensesCursor = Self.latest(state.expensesCursor, remoteExpenses.compactMap(\.serverUpdatedAt))
    }

    // Devuelve las categorías locales por id, ya actualizadas, para enlazar los gastos.
    private func apply(_ remoteCategories: [RemoteCategory]) -> [UUID: ExpenseCategory] {
        var locals = Dictionary(allCategories().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Una categoría borrada aquí y aún no subida no debe resucitar por un cambio que llega de fuera.
        let tombstoneIDs = Set(state.categoryTombstones.map(\.id))

        for remoteCategory in remoteCategories where !tombstoneIDs.contains(remoteCategory.id) {
            if let local = locals[remoteCategory.id] {
                guard !Self.localWins(local.syncStatus, local.localLastModified, over: remoteCategory.updatedAt) else { continue }
                if remoteCategory.isDeleted {
                    // Sus gastos quedan sin categoría; el móvil que la borró ya los habrá movido y esos
                    // cambios llegan en esta misma pasada.
                    context.delete(local)
                    locals[remoteCategory.id] = nil
                } else {
                    local.update(from: remoteCategory)
                }
            } else if !remoteCategory.isDeleted {
                let category = ExpenseCategory(
                    id: remoteCategory.id,
                    name: remoteCategory.name,
                    symbolName: remoteCategory.symbolName,
                    sortOrder: remoteCategory.sortOrder
                )
                category.update(from: remoteCategory)
                context.insert(category)
                locals[remoteCategory.id] = category
            }
        }
        return locals
    }

    private func apply(_ remoteExpenses: [RemoteExpense], categoriesByID: [UUID: ExpenseCategory]) {
        guard !remoteExpenses.isEmpty else { return }
        let locals = Dictionary(allExpenses().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for remoteExpense in remoteExpenses {
            if let local = locals[remoteExpense.id] {
                guard !Self.localWins(local.syncStatus, local.localLastModified, over: remoteExpense.updatedAt) else { continue }
                if remoteExpense.isDeleted {
                    context.delete(local)
                } else {
                    local.update(from: remoteExpense, categoriesByID: categoriesByID)
                }
            } else if !remoteExpense.isDeleted {
                let expense = Expense(id: remoteExpense.id, amount: remoteExpense.amount)
                expense.update(from: remoteExpense, categoriesByID: categoriesByID)
                context.insert(expense)
            }
        }
    }

    // Lo local solo gana si tiene cambios sin subir posteriores a la versión del servidor. Con la misma
    // fecha es la misma escritura (la nuestra, de vuelta) y da igual cuál se quede.
    static func localWins(_ status: SyncStatus, _ localModified: Date, over remoteModified: Date) -> Bool {
        status == .pending && localModified > remoteModified
    }

    private static func pullStart(after cursor: Date?) -> Date? {
        cursor.map { $0.addingTimeInterval(-pullOverlap) }
    }

    private static func latest(_ cursor: Date?, _ dates: [Date]) -> Date? {
        ([cursor].compactMap { $0 } + dates).max()
    }

    // MARK: - Subir

    private func push() async throws -> Int {
        // Primero las categorías: los gastos las referencian en el servidor.
        let tombstones = state.categoryTombstones
        let categoryRows = allCategories().filter { $0.syncStatus == .pending }.map { RemoteCategory($0) }
        for batch in (categoryRows + tombstones).chunked(into: Self.pushBatchSize) {
            try await remote.upsertCategories(batch)
        }
        // Lo que se ha cambiado mientras se subía queda pendiente para la próxima vez.
        let sentCategoryDates = Dictionary(categoryRows.map { ($0.id, $0.updatedAt) }, uniquingKeysWith: { first, _ in first })
        var pendingCategoryCount = 0
        for category in allCategories() {
            if sentCategoryDates[category.id] == category.localLastModified {
                category.syncStatus = .synced
            } else if category.syncStatus == .pending {
                pendingCategoryCount += 1
            }
        }
        state.categoryTombstones = state.categoryTombstones.filter { !tombstones.contains($0) }
        try context.save()

        let expenseRows = allExpenses().filter { $0.syncStatus == .pending }.map { RemoteExpense($0) }
        var syncedExpenseCount = 0
        for batch in expenseRows.chunked(into: Self.pushBatchSize) {
            try await remote.upsertExpenses(batch)
            let sentDates = Dictionary(batch.map { ($0.id, $0.updatedAt) }, uniquingKeysWith: { first, _ in first })
            for expense in expenses(withIDs: Array(sentDates.keys)) where sentDates[expense.id] == expense.localLastModified {
                // Un borrado ya subido no hace falta guardarlo más: el servidor conserva la marca.
                if expense.isSoftDeleted {
                    context.delete(expense)
                } else {
                    expense.syncStatus = .synced
                }
                syncedExpenseCount += 1
            }
            try context.save()
        }
        // Lo que se modifique a partir de aquí lo cuenta la siguiente pasada, que ya habrá pedido requestSync.
        return pendingCategoryCount + state.categoryTombstones.count + expenseRows.count - syncedExpenseCount
    }

    // MARK: - Lecturas

    private func allCategories() -> [ExpenseCategory] {
        context.categories(failureMessage: "Fallo al leer las categorías para sincronizar")
    }

    private func allExpenses() -> [Expense] {
        context.fetchOrEmpty(FetchDescriptor<Expense>(), failureMessage: "Fallo al leer los gastos para sincronizar")
    }

    private func expenses(withIDs ids: [UUID]) -> [Expense] {
        context.fetchOrEmpty(
            FetchDescriptor<Expense>(predicate: #Predicate { ids.contains($0.id) }),
            failureMessage: "Fallo al leer los gastos recién subidos"
        )
    }
}

extension Expense {
    func markPendingSync() {
        localLastModified = .now
        syncStatus = .pending
    }

    fileprivate func update(from remote: RemoteExpense, categoriesByID: [UUID: ExpenseCategory]) {
        amount = remote.amount
        date = remote.date
        title = remote.title
        paymentMethod = PaymentMethod(serverCode: remote.paymentMethod) ?? .other
        category = remote.categoryID.flatMap { categoriesByID[$0] }
        isSoftDeleted = false
        createdAt = remote.createdAt
        localLastModified = remote.updatedAt
        syncStatus = .synced
    }
}

extension ExpenseCategory {
    func markPendingSync() {
        localLastModified = .now
        syncStatus = .pending
    }

    fileprivate func update(from remote: RemoteCategory) {
        name = remote.name
        symbolName = remote.symbolName
        sortOrder = remote.sortOrder
        color = remote.colorName.flatMap(CategoryColor.init(rawValue:))
        localLastModified = remote.updatedAt
        syncStatus = .synced
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
