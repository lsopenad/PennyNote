import Foundation

// Lo que la sincronización necesita del servidor. Es un protocolo para poder probar SyncEngine sin
// red; la implementación real es SupabaseSyncRemote.
protocol SyncRemote {
    func upsertCategories(_ categories: [RemoteCategory]) async throws
    func upsertExpenses(_ expenses: [RemoteExpense]) async throws
    func upsertRecurringExpenses(_ recurringExpenses: [RemoteRecurringExpense]) async throws
    // Filas cambiadas en el servidor después de `since` (todas si es nil), por server_updated_at.
    func fetchCategories(changedSince since: Date?) async throws -> [RemoteCategory]
    func fetchExpenses(changedSince since: Date?) async throws -> [RemoteExpense]
    func fetchRecurringExpenses(changedSince since: Date?) async throws -> [RemoteRecurringExpense]
    // La fila de ajustes de la cuenta, o nil si aún no tiene.
    func fetchUserSettings() async throws -> RemoteUserSettings?
    func upsertUserSettings(_ settings: RemoteUserSettings) async throws
}

// Lo común de las filas que se bajan, para paginar por server_updated_at.
protocol SyncRow {
    var id: UUID { get }
    var serverUpdatedAt: Date? { get }
}

// Fila de public.categories. user_id no viaja: lo pone el servidor a partir de la sesión.
struct RemoteCategory: Codable, Equatable, SyncRow {
    let id: UUID
    var name: String
    // CategoryIcon.storedValue.
    var icon: String
    // CategoryColor.storedValue, o nil sin color.
    var color: String?
    var sortOrder: Int
    var isDeleted: Bool
    var updatedAt: Date
    // Solo viene del servidor; no se envía porque lo pone un trigger.
    var serverUpdatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, color
        case sortOrder = "sort_order"
        case isDeleted = "is_deleted"
        case updatedAt = "updated_at"
        case serverUpdatedAt = "server_updated_at"
        // Nombre de icon hasta la 1.9.1, con el que se guardaron los borrados pendientes de subir.
        case legacySymbolName = "symbol_name"
    }

    init(
        id: UUID,
        name: String,
        icon: String,
        color: String? = nil,
        sortOrder: Int,
        isDeleted: Bool,
        updatedAt: Date,
        serverUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.sortOrder = sortOrder
        self.isDeleted = isDeleted
        self.updatedAt = updatedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
            ?? container.decode(String.self, forKey: .legacySymbolName)
        // No viene en los borrados pendientes guardados por la 1.11.0 y anteriores.
        color = try container.decodeIfPresent(String.self, forKey: .color)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        isDeleted = try container.decode(Bool.self, forKey: .isDeleted)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        serverUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .serverUpdatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
        // Siempre, también como null: quitar el color tiene que borrarlo en el servidor.
        try container.encode(color, forKey: .color)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// Fila de public.expenses. El importe viaja como texto para no perder precisión (ver DecimalText).
struct RemoteExpense: Codable, Equatable, SyncRow {
    let id: UUID
    var amount: Decimal
    var date: Date
    var title: String
    // PaymentMethod.serverCode.
    var paymentMethod: String
    var categoryID: UUID?
    // RecurringExpense que lo creó.
    var recurringExpenseID: UUID?
    var isDeleted: Bool
    var createdAt: Date
    var updatedAt: Date
    var serverUpdatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, amount, date, title
        case paymentMethod = "payment_method"
        case categoryID = "category_id"
        case recurringExpenseID = "recurring_expense_id"
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case serverUpdatedAt = "server_updated_at"
    }

    init(
        id: UUID,
        amount: Decimal,
        date: Date,
        title: String,
        paymentMethod: String,
        categoryID: UUID?,
        recurringExpenseID: UUID? = nil,
        isDeleted: Bool,
        createdAt: Date,
        updatedAt: Date,
        serverUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.title = title
        self.paymentMethod = paymentMethod
        self.categoryID = categoryID
        self.recurringExpenseID = recurringExpenseID
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        amount = try container.decode(DecimalText.self, forKey: .amount).value
        date = try container.decode(Date.self, forKey: .date)
        title = try container.decode(String.self, forKey: .title)
        paymentMethod = try container.decode(String.self, forKey: .paymentMethod)
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        recurringExpenseID = try container.decodeIfPresent(UUID.self, forKey: .recurringExpenseID)
        isDeleted = try container.decode(Bool.self, forKey: .isDeleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        serverUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .serverUpdatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(DecimalText(amount), forKey: .amount)
        try container.encode(date, forKey: .date)
        try container.encode(title, forKey: .title)
        try container.encode(paymentMethod, forKey: .paymentMethod)
        try container.encode(categoryID, forKey: .categoryID)
        try container.encode(recurringExpenseID, forKey: .recurringExpenseID)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// Fila de public.recurring_expenses: la plantilla de un gasto recurrente.
struct RemoteRecurringExpense: Codable, Equatable, SyncRow {
    let id: UUID
    var amount: Decimal
    var title: String
    // PaymentMethod.serverCode.
    var paymentMethod: String
    var categoryID: UUID?
    // RecurrenceFrequency.serverCode.
    var frequency: String
    var startDate: Date
    var nextDate: Date
    var isPaused: Bool
    var isDeleted: Bool
    var createdAt: Date
    var updatedAt: Date
    var serverUpdatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, amount, title, frequency
        case paymentMethod = "payment_method"
        case categoryID = "category_id"
        case startDate = "start_date"
        case nextDate = "next_date"
        case isPaused = "is_paused"
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case serverUpdatedAt = "server_updated_at"
    }

    init(
        id: UUID,
        amount: Decimal,
        title: String,
        paymentMethod: String,
        categoryID: UUID?,
        frequency: String,
        startDate: Date,
        nextDate: Date,
        isPaused: Bool,
        isDeleted: Bool,
        createdAt: Date,
        updatedAt: Date,
        serverUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.amount = amount
        self.title = title
        self.paymentMethod = paymentMethod
        self.categoryID = categoryID
        self.frequency = frequency
        self.startDate = startDate
        self.nextDate = nextDate
        self.isPaused = isPaused
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        amount = try container.decode(DecimalText.self, forKey: .amount).value
        title = try container.decode(String.self, forKey: .title)
        paymentMethod = try container.decode(String.self, forKey: .paymentMethod)
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        frequency = try container.decode(String.self, forKey: .frequency)
        startDate = try container.decode(Date.self, forKey: .startDate)
        nextDate = try container.decode(Date.self, forKey: .nextDate)
        isPaused = try container.decode(Bool.self, forKey: .isPaused)
        isDeleted = try container.decode(Bool.self, forKey: .isDeleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        serverUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .serverUpdatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(DecimalText(amount), forKey: .amount)
        try container.encode(title, forKey: .title)
        try container.encode(paymentMethod, forKey: .paymentMethod)
        try container.encode(categoryID, forKey: .categoryID)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(nextDate, forKey: .nextDate)
        try container.encode(isPaused, forKey: .isPaused)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// Fila de public.user_settings. Hay una por usuario y se identifica por user_id, que pone el servidor.
struct RemoteUserSettings: Codable, Equatable {
    // AppCurrency.rawValue.
    var currency: String
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case currency
        case updatedAt = "updated_at"
    }
}

extension RemoteCategory {
    init(_ category: ExpenseCategory, isDeleted: Bool = false) {
        self.init(
            id: category.id,
            name: category.name,
            icon: category.icon.storedValue,
            color: category.color?.storedValue,
            sortOrder: category.sortOrder,
            isDeleted: isDeleted,
            updatedAt: category.localLastModified
        )
    }
}

extension RemoteExpense {
    init(_ expense: Expense) {
        self.init(
            id: expense.id,
            amount: expense.amount,
            date: expense.date,
            title: expense.title,
            paymentMethod: expense.paymentMethod.serverCode,
            categoryID: expense.category?.id,
            recurringExpenseID: expense.recurringExpenseID,
            isDeleted: expense.isSoftDeleted,
            createdAt: expense.createdAt,
            updatedAt: expense.localLastModified
        )
    }
}

extension RemoteRecurringExpense {
    init(_ recurringExpense: RecurringExpense) {
        self.init(
            id: recurringExpense.id,
            amount: recurringExpense.amount,
            title: recurringExpense.title,
            paymentMethod: recurringExpense.paymentMethod.serverCode,
            categoryID: recurringExpense.category?.id,
            frequency: recurringExpense.frequency.serverCode,
            startDate: recurringExpense.startDate,
            nextDate: recurringExpense.nextDate,
            isPaused: recurringExpense.isPaused,
            isDeleted: recurringExpense.isSoftDeleted,
            createdAt: recurringExpense.createdAt,
            updatedAt: recurringExpense.localLastModified
        )
    }
}
