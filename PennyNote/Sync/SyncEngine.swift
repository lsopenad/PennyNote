import Foundation
import SwiftData
import os

actor SyncEngine {
    static let shared = SyncEngine()

    private var modelContainer: ModelContainer?
    private var isSyncing = false

    private init() {}

    func configure(container: ModelContainer) {
        modelContainer = container
    }

    func syncNow() async {
        guard !isSyncing else { return }
        guard let modelContainer else { return }
        guard let token = NotionCredentialsStore.token, let databaseID = SyncStateStore.notionDatabaseID else {
            return // Notion no configurado todavía: no-op.
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
            let total = MonthlyTotalCalculator.total(in: context)
            let monthStart = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
            MonthlyTotalStore.write(total: total, monthStart: monthStart)
        } catch {
            SyncStateStore.lastSyncError = error.localizedDescription
        }
    }

    func pushCategorySchema() async {
        guard let modelContainer, let token = NotionCredentialsStore.token, let databaseID = SyncStateStore.notionDatabaseID else { return }
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

    // MARK: - Push

    private func push(context: ModelContext, client: NotionClient, databaseID: String) async throws {
        let pendingStatus = SyncStatus.pending
        let descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.syncStatus == pendingStatus })
        let pendingExpenses = (try? context.fetch(descriptor)) ?? []

        for expense in pendingExpenses {
            do {
                if expense.isDeleted {
                    if let pageID = expense.notionPageID {
                        _ = try await withRateLimitRetry {
                            try await client.updatePage(
                                pageID: pageID,
                                amount: expense.amount,
                                date: expense.date,
                                title: expense.title,
                                paymentMethod: expense.paymentMethod,
                                categoryName: expense.category?.name,
                                archived: true
                            )
                        }
                    }
                    context.delete(expense)
                    continue
                }

                if let pageID = expense.notionPageID {
                    let page = try await withRateLimitRetry {
                        try await client.updatePage(
                            pageID: pageID,
                            amount: expense.amount,
                            date: expense.date,
                            title: expense.title,
                            paymentMethod: expense.paymentMethod,
                            categoryName: expense.category?.name,
                            archived: false
                        )
                    }
                    expense.notionLastEditedTime = page.lastEditedTime
                    expense.syncStatus = .synced
                } else {
                    let page = try await withRateLimitRetry {
                        try await client.createPage(
                            databaseID: databaseID,
                            amount: expense.amount,
                            date: expense.date,
                            title: expense.title,
                            paymentMethod: expense.paymentMethod,
                            categoryName: expense.category?.name
                        )
                    }
                    expense.notionPageID = page.id
                    expense.notionLastEditedTime = page.lastEditedTime
                    expense.syncStatus = .synced
                }
            } catch {
                // Se reintenta en el siguiente ciclo de sync; no bloquea el resto del lote.
                Log.sync.error("Fallo al sincronizar el gasto \(expense.id) con Notion: \(error.localizedDescription)")
                continue
            }
        }
    }

    // MARK: - Pull

    private func pull(context: ModelContext, client: NotionClient, databaseID: String) async throws {
        let since = SyncStateStore.lastSyncDate
        var cursor: String?
        var allPages: [ParsedNotionPage] = []

        repeat {
            let result = try await withRateLimitRetry {
                try await client.queryDatabase(databaseID: databaseID, editedAfter: since, cursor: cursor)
            }
            allPages.append(contentsOf: result.pages)
            cursor = result.hasMore ? result.nextCursor : nil
        } while cursor != nil

        let categories = (try? context.fetch(FetchDescriptor<ExpenseCategory>())) ?? []

        for remotePage in allPages {
            let targetPageID = remotePage.id
            let expenseDescriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.notionPageID == targetPageID })
            let localMatch = (try? context.fetch(expenseDescriptor))?.first

            if remotePage.archived {
                if let localMatch { context.delete(localMatch) }
                continue
            }

            let matchedCategory = categories.first { $0.name == remotePage.categoryName }

            if let local = localMatch {
                let shouldRemoteWin: Bool
                switch local.syncStatus {
                case .synced:
                    shouldRemoteWin = true
                case .pending, .conflict:
                    shouldRemoteWin = ConflictResolver.remoteWins(
                        localLastModified: local.localLastModified,
                        remoteLastEditedTime: remotePage.lastEditedTime
                    )
                }

                if shouldRemoteWin {
                    local.amount = remotePage.amount
                    local.date = remotePage.date
                    local.title = remotePage.title
                    local.paymentMethod = remotePage.paymentMethod
                    local.category = matchedCategory
                    local.notionLastEditedTime = remotePage.lastEditedTime
                    local.syncStatus = .synced
                }
            } else {
                let newExpense = Expense(
                    amount: remotePage.amount,
                    date: remotePage.date,
                    title: remotePage.title,
                    paymentMethod: remotePage.paymentMethod,
                    category: matchedCategory
                )
                newExpense.notionPageID = remotePage.id
                newExpense.notionLastEditedTime = remotePage.lastEditedTime
                newExpense.syncStatus = .synced
                context.insert(newExpense)
            }
        }
    }

    // MARK: - Rate limiting

    private func withRateLimitRetry<T>(_ operation: () async throws -> T) async throws -> T {
        var attempts = 0
        while true {
            do {
                return try await operation()
            } catch NotionError.rateLimited(let retryAfter) {
                attempts += 1
                guard attempts < 3 else { throw NotionError.rateLimited(retryAfter: retryAfter) }
                try? await Task.sleep(for: .seconds(retryAfter))
            }
        }
    }
}
