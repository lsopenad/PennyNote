import Foundation
import SwiftData
import os

actor SyncEngine {
    static let shared = SyncEngine()

    // Intentos ante el límite de peticiones de Notion (429) antes de dar por fallida la operación.
    private static let maxRateLimitAttempts = 3

    // Se usa directamente el contenedor compartido: configurarlo desde App.init en un Task suelto
    // dejaba una ventana en la que el primer sync (al pasar a .active) no hacía nada.
    private let modelContainer = SharedModelContainer.container
    private var isSyncing = false

    private init() {}

    func syncNow() async {
        guard !isSyncing else {
            Log.sync.debug("Sync omitido: ya hay uno en curso")
            return
        }
        guard let token = NotionCredentialsStore.token, let databaseID = SyncStateStore.notionDatabaseID else {
            Log.sync.debug("Sync omitido: Notion no está configurado todavía")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let context = ModelContext(modelContainer)
        let client = NotionClient(token: token)

        do {
            // Sana el esquema remoto (categorías + campos Título/Método de pago) antes de
            // sincronizar, por si la base de datos se conectó antes de que existieran estos campos.
            await pushCategorySchema()
            try await push(context: context, client: client, databaseID: databaseID)
            try await pull(context: context, client: client, databaseID: databaseID)
            try context.save()
            SyncStateStore.lastSyncDate = .now
            SyncStateStore.lastSyncError = nil
            MonthlyTotalCalculator.refreshSharedTotal(in: context)
        } catch {
            Log.sync.error("Fallo en la sincronización con Notion: \(error.localizedDescription)")
            SyncStateStore.lastSyncError = error.localizedDescription
        }
    }

    func pushCategorySchema() async {
        guard let token = NotionCredentialsStore.token, let databaseID = SyncStateStore.notionDatabaseID else { return }
        let context = ModelContext(modelContainer)
        let categories: [ExpenseCategory]
        do {
            categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        } catch {
            Log.sync.error("Fallo al leer categorías para sincronizar el esquema con Notion: \(error.localizedDescription)")
            return
        }
        let names = categories.map(\.name)
        let client = NotionClient(token: token)
        do {
            try await client.updateCategorySchema(databaseID: databaseID, categoryNames: names)
        } catch {
            Log.sync.error("Fallo al actualizar el esquema de categorías en Notion: \(error.localizedDescription)")
        }
    }

    // MARK: - Subida

    private func push(context: ModelContext, client: NotionClient, databaseID: String) async throws {
        let pendingStatus = SyncStatus.pending
        let descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.syncStatus == pendingStatus })

        for expense in try context.fetch(descriptor) {
            do {
                try await push(expense, context: context, client: client, databaseID: databaseID)
            } catch {
                // Se reintenta en el siguiente ciclo de sync; no bloquea el resto del lote.
                Log.sync.error("Fallo al sincronizar el gasto \(expense.id) con Notion: \(error.localizedDescription)")
            }
        }
    }

    private func push(_ expense: Expense, context: ModelContext, client: NotionClient, databaseID: String) async throws {
        let fields = NotionExpenseFields(expense)

        if expense.isDeleted {
            // Si nunca llegó a Notion no hay página que archivar.
            if let pageID = expense.notionPageID {
                _ = try await withRateLimitRetry {
                    try await client.updatePage(pageID: pageID, fields: fields, archived: true)
                }
            }
            context.delete(expense)
            return
        }

        let page: ParsedNotionPage
        if let pageID = expense.notionPageID {
            page = try await withRateLimitRetry {
                try await client.updatePage(pageID: pageID, fields: fields, archived: false)
            }
        } else {
            page = try await withRateLimitRetry {
                try await client.createPage(databaseID: databaseID, fields: fields)
            }
            expense.notionPageID = page.id
        }
        expense.notionLastEditedTime = page.lastEditedTime
        expense.syncStatus = .synced
    }

    // MARK: - Bajada

    private func pull(context: ModelContext, client: NotionClient, databaseID: String) async throws {
        let remotePages = try await fetchRemotePages(client: client, databaseID: databaseID, editedAfter: SyncStateStore.lastSyncDate)

        let categoriesByName = Dictionary(
            try context.fetch(FetchDescriptor<ExpenseCategory>()).map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        // Una sola lectura de los gastos ya enlazados con Notion en vez de una búsqueda por página.
        let linkedExpenses = try context.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.notionPageID != nil }))
        var localByPageID = Dictionary(
            linkedExpenses.compactMap { expense in expense.notionPageID.map { ($0, expense) } },
            uniquingKeysWith: { first, _ in first }
        )

        for remotePage in remotePages {
            let localMatch = localByPageID[remotePage.id]

            if remotePage.archived {
                if let localMatch {
                    context.delete(localMatch)
                    localByPageID[remotePage.id] = nil
                }
                continue
            }

            let category = remotePage.categoryName.flatMap { categoriesByName[$0] }

            if let local = localMatch {
                // Sin cambios locales pendientes manda Notion; con cambios, gana la edición más reciente.
                let remoteWins = local.syncStatus == .synced || ConflictResolver.remoteWins(
                    localLastModified: local.localLastModified,
                    remoteLastEditedTime: remotePage.lastEditedTime
                )
                if remoteWins {
                    apply(remotePage, category: category, to: local)
                }
            } else {
                let newExpense = Expense(amount: remotePage.amount)
                newExpense.notionPageID = remotePage.id
                apply(remotePage, category: category, to: newExpense)
                context.insert(newExpense)
                localByPageID[remotePage.id] = newExpense
            }
        }
    }

    private func fetchRemotePages(client: NotionClient, databaseID: String, editedAfter: Date?) async throws -> [ParsedNotionPage] {
        var cursor: String?
        var pages: [ParsedNotionPage] = []
        repeat {
            let result = try await withRateLimitRetry {
                try await client.queryDatabase(databaseID: databaseID, editedAfter: editedAfter, cursor: cursor)
            }
            pages.append(contentsOf: result.pages)
            cursor = result.hasMore ? result.nextCursor : nil
        } while cursor != nil
        return pages
    }

    private func apply(_ remotePage: ParsedNotionPage, category: ExpenseCategory?, to expense: Expense) {
        expense.amount = remotePage.amount
        expense.date = remotePage.date
        // Un título vacío se envía a Notion como fallbackTitle; al volver no debe sustituir al vacío local.
        let isEchoedFallbackTitle = remotePage.title == NotionMapper.fallbackTitle && expense.title.isEmpty
        expense.title = isEchoedFallbackTitle ? "" : remotePage.title
        expense.paymentMethod = remotePage.paymentMethod
        expense.category = category
        expense.notionLastEditedTime = remotePage.lastEditedTime
        expense.syncStatus = .synced
    }

    // MARK: - Límite de peticiones

    private func withRateLimitRetry<T>(_ operation: () async throws -> T) async throws -> T {
        var attempts = 0
        while true {
            do {
                return try await operation()
            } catch NotionError.rateLimited(let retryAfter) {
                attempts += 1
                guard attempts < Self.maxRateLimitAttempts else { throw NotionError.rateLimited(retryAfter: retryAfter) }
                try? await Task.sleep(for: .seconds(retryAfter))
            }
        }
    }
}
