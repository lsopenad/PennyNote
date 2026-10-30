import Foundation
import Supabase

// SyncRemote contra las tablas public.categories, public.expenses, public.recurring_expenses y public.user_settings. RLS limita cada consulta a las
// filas del usuario de la sesión, así que no hace falta filtrar por user_id.
struct SupabaseSyncRemote: SyncRemote {
    // El máximo de filas que devuelve PostgREST por petición en Supabase (max_rows).
    static let pageSize = 1000

    private static let categoryColumns = "id,name,symbol_name,sort_order,color_name,is_deleted,updated_at,server_updated_at"
    // amount::text: el importe llega como texto y no pierde precisión al decodificarlo.
    private static let expenseColumns = "id,amount::text,date,title,payment_method,category_id,recurring_expense_id,is_deleted,created_at,updated_at,server_updated_at"
    private static let recurringExpenseColumns = "id,amount::text,title,payment_method,category_id,frequency,start_date,next_date,is_paused,is_deleted,created_at,updated_at,server_updated_at"

    private static let userSettingsColumns = "currency,updated_at,server_updated_at"

    let client: SupabaseClient

    func upsertCategories(_ categories: [RemoteCategory]) async throws {
        try await client.from("categories")
            .upsert(categories, onConflict: "id", returning: .minimal)
            .execute()
    }

    func upsertExpenses(_ expenses: [RemoteExpense]) async throws {
        try await client.from("expenses")
            .upsert(expenses, onConflict: "id", returning: .minimal)
            .execute()
    }

    func upsertRecurringExpenses(_ recurringExpenses: [RemoteRecurringExpense]) async throws {
        try await client.from("recurring_expenses")
            .upsert(recurringExpenses, onConflict: "id", returning: .minimal)
            .execute()
    }

    func fetchCategories(changedSince since: Date?) async throws -> [RemoteCategory] {
        try await fetchAll(table: "categories", columns: Self.categoryColumns, changedSince: since)
    }

    func fetchExpenses(changedSince since: Date?) async throws -> [RemoteExpense] {
        try await fetchAll(table: "expenses", columns: Self.expenseColumns, changedSince: since)
    }

    func fetchRecurringExpenses(changedSince since: Date?) async throws -> [RemoteRecurringExpense] {
        try await fetchAll(table: "recurring_expenses", columns: Self.recurringExpenseColumns, changedSince: since)
    }

    func fetchUserSettings() async throws -> RemoteUserSettings? {
        let rows: [RemoteUserSettings] = try await client.from("user_settings")
            .select(Self.userSettingsColumns)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    // user_id no viaja: al crear la fila lo pone el valor por defecto (auth.uid()), y el conflicto se
    // detecta con él.
    func upsertUserSettings(_ settings: RemoteUserSettings) async throws {
        try await client.from("user_settings")
            .upsert(settings, onConflict: "user_id", returning: .minimal)
            .execute()
    }

    // Pide página a página, cada una desde el server_updated_at de la última fila recibida (no por
    // offset: si otro dispositivo cambia una fila ya leída, las demás se desplazarían y una se perdería).
    // Se empieza 1 ms antes porque las fechas viajan con milisegundos y el servidor guarda
    // microsegundos; las filas repetidas se descartan.
    private func fetchAll<Row: Decodable & SyncRow>(table: String, columns: String, changedSince since: Date?) async throws -> [Row] {
        var rowsByID: [UUID: Row] = [:]
        var start = since
        while true {
            var query = client.from(table).select(columns)
            if let start {
                query = query.gte("server_updated_at", value: start)
            }
            let page: [Row] = try await query
                .order("server_updated_at")
                .order("id")
                .limit(Self.pageSize)
                .execute()
                .value
            page.forEach { rowsByID[$0.id] = $0 }

            guard page.count == Self.pageSize, let last = page.last?.serverUpdatedAt else {
                return rowsByID.values.sorted { ($0.serverUpdatedAt ?? .distantPast) < ($1.serverUpdatedAt ?? .distantPast) }
            }
            let next = last.addingTimeInterval(-0.001)
            // Una página entera con la misma fecha no deja avanzar. No debería pasar: se sube en lotes
            // de SyncEngine.pushBatchSize, menos que una página.
            guard next > (start ?? .distantPast) else {
                throw SyncPagingError.pageWithoutProgress(table: table)
            }
            start = next
        }
    }
}

enum SyncPagingError: Error {
    case pageWithoutProgress(table: String)
}
