import Foundation
import SwiftData
import Testing
@testable import PennyNote

// Mediciones de las rutas calientes con 1k, 10k y 50k gastos de DebugSeed. No comprueban nada: solo
// imprimen tiempos ("BENCH …") y no se ejecutan con el resto de tests. Para lanzarlas:
//
//   TEST_RUNNER_PENNYNOTE_BENCHMARKS=1 xcodebuild test -project PennyNote.xcodeproj -scheme PennyNote \
//     -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PennyNoteTests/PerformanceBenchmarks
//
// Cada medida reproduce lo que hace una vista en una evaluación de body, sobre gastos ya cargados.
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["PENNYNOTE_BENCHMARKS"] == "1"))
struct PerformanceBenchmarks {
    static let sizes = [1_000, 10_000, 50_000]

    @Test(arguments: sizes)
    func screens(expenseCount: Int) throws {
        let context = try Self.seededContext(expenseCount)
        let newestFirst = FetchDescriptor<Expense>(predicate: #Predicate { !$0.isSoftDeleted }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        let oldestFirst = FetchDescriptor<Expense>(predicate: #Predicate { !$0.isSoftDeleted }, sortBy: [SortDescriptor(\.date)])

        Self.measure("fetch.activeExpenses", expenseCount) { _ = try? context.fetch(newestFirst) }
        let expenses = try context.fetch(newestFirst)
        let ascending = try context.fetch(oldestFirst)

        // ExpenseDayList: lista filtrada, primera página agrupada por día, y cabecera del mes.
        let filter = ExpenseFilter()
        Self.measure("list.filterAndPage", expenseCount) {
            let visible = ExpenseDayList.visibleExpenses(expenses.filter(filter.matches), limit: ExpenseDayList.pageSize)
            let calendar = Calendar.current
            _ = Dictionary(grouping: visible) { calendar.startOfDay(for: $0.date) }.sorted { $0.key > $1.key }
        }
        // ExpenseSearchOverlay con una letra: casi todos los gastos coinciden.
        Self.measure("search.filterAndPage", expenseCount) {
            let results = ExpenseSearchOverlay.results(expenses, matching: "a")
            let visible = ExpenseDayList.visibleExpenses(results, limit: ExpenseDayList.pageSize)
            let calendar = Calendar.current
            _ = Dictionary(grouping: visible) { calendar.startOfDay(for: $0.date) }.sorted { $0.key > $1.key }
        }
        Self.measure("list.monthHeader", expenseCount) {
            let now = Date.now
            let previous = Calendar.current.startOfPreviousMonth(for: now) ?? now
            _ = SpendingStatistics.monthSpending(expenses, monthOf: now)
            _ = SpendingStatistics.monthSpending(expenses, monthOf: previous)
        }

        // StatisticsView en modo mes.
        let period = StatisticsPeriod(kind: .month, containing: .now)
        Self.measure("statistics.body", expenseCount) {
            let periodExpenses = SpendingStatistics.expenses(ascending, in: period)
            let elapsedDays = SpendingStatistics.elapsedDays(in: period)
            _ = SpendingStatistics.dailyAverage(SpendingStatistics.dailyTotals(periodExpenses, in: period), elapsedDays: elapsedDays)
            _ = SpendingStatistics.dailyTotals(periodExpenses, in: period)
            _ = SpendingStatistics.categoryTotals(periodExpenses)
            _ = SpendingStatistics.paymentMethodTotals(periodExpenses)
            _ = SpendingStatistics.periodTotals(ascending, endingIn: period, count: 6)
        }

        // ExportView con «Todo»: prepara las filas en cada evaluación de body.
        Self.measure("export.body", expenseCount) { _ = ExportRow.rows(for: ascending) }

        Self.measure("widget.refresh", expenseCount) { WidgetSnapshotRefresher.refresh(in: context) }
    }

    @Test(arguments: sizes)
    func export(expenseCount: Int) throws {
        let context = try Self.seededContext(expenseCount)
        let rows = ExportRow.rows(for: try context.fetch(FetchDescriptor<Expense>()))
        let url = FileManager.default.temporaryDirectory.appending(path: "benchmark-\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: url) }

        Self.measure("export.csv", expenseCount, iterations: 3) { _ = CSVExporter.data(for: rows, currency: .eur) }
        Self.measure("export.excel", expenseCount, iterations: 3) {
            try? ExcelExporter.write(rows, to: url, currency: .eur, periodTitle: "Benchmark")
        }
    }

    @Test(arguments: sizes)
    func sync(expenseCount: Int) async throws {
        // Primera subida: todo pendiente.
        let pushContext = try Self.seededContext(expenseCount)
        let pushState = try Self.syncState()
        let currency = CurrencySettings(defaults: try #require(UserDefaults(suiteName: "PerformanceBenchmarks.currency.\(UUID())")))
        Self.measure("sync.pendingChangeCount", expenseCount) {
            _ = SyncEngine.pendingChangeCount(context: pushContext, state: pushState, currency: currency)
        }
        let pushEngine = SyncEngine(context: pushContext, remote: FakeSyncRemote(), state: pushState, currency: currency)
        try pushEngine.prepareLocalData(for: UUID())
        let pushStart = ContinuousClock.now
        try await pushEngine.sync()
        Self.report("sync.firstPush", expenseCount, [ContinuousClock.now - pushStart])

        // Instalación nueva que baja todo de la cuenta.
        let remote = FakeSyncRemote()
        for index in 0..<expenseCount {
            remote.add(expense: Decimal(index % 5_000) / 100)
        }
        let pullContext = try Self.emptyContext()
        let pullEngine = SyncEngine(context: pullContext, remote: remote, state: try Self.syncState(), currency: currency)
        try pullEngine.prepareLocalData(for: UUID())
        let pullStart = ContinuousClock.now
        try await pullEngine.sync()
        Self.report("sync.firstPull", expenseCount, [ContinuousClock.now - pullStart])

        // Pasada sin cambios, la habitual al volver a la app.
        let idleStart = ContinuousClock.now
        try await pullEngine.sync()
        Self.report("sync.idlePass", expenseCount, [ContinuousClock.now - idleStart])
    }

    @Test func formatting() {
        Self.measure("currency.symbol x1000", 0) {
            for _ in 0..<1_000 { _ = AppCurrency.eur.symbol }
        }
        Self.measure("displayFormat.currency x1000", 0) {
            for index in 0..<1_000 { _ = DisplayFormat.currency(Decimal(index) / 100, in: .eur) }
        }
    }

    // MARK: - Utilidades

    private static func emptyContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, RecurringExpense.self, configurations: configuration)
        return ModelContext(container)
    }

    private static func seededContext(_ expenseCount: Int) throws -> ModelContext {
        let context = try emptyContext()
        DebugSeed.populate(context, dailyExpenseCount: expenseCount)
        try context.save()
        return context
    }

    private static func syncState() throws -> SyncStateStore {
        SyncStateStore(defaults: try #require(UserDefaults(suiteName: "PerformanceBenchmarks.\(UUID())")))
    }

    // La primera vuelta se informa aparte: incluye cargar los atributos de los gastos (faults).
    private static func measure(_ name: String, _ expenseCount: Int, iterations: Int = 7, _ work: () -> Void) {
        let clock = ContinuousClock()
        let durations = (0..<iterations).map { _ in clock.measure(work) }
        report(name, expenseCount, durations)
    }

    private static func report(_ name: String, _ expenseCount: Int, _ durations: [Duration]) {
        let milliseconds = durations.map { Double($0.components.attoseconds) / 1e15 + Double($0.components.seconds) * 1_000 }
        let median = milliseconds.dropFirst().sorted().dropFirst(max(milliseconds.count - 1, 0) / 2).first ?? milliseconds[0]
        print(String(format: "BENCH %@ n=%d first=%.2fms median=%.2fms", name, expenseCount, milliseconds[0], median))
    }
}
