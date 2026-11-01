import Foundation
import SwiftData

// Datos de prueba para capturas y mediciones, solo en Debug. Con el argumento de lanzamiento
// `-DebugSeed YES` la app abre con una sesión ficticia, sin sincronizar, sobre un almacén propio del
// App Group que se vuelve a rellenar en cada arranque. Por defecto son unos seis meses de gastos;
// `-DebugSeedExpenses N` pide N gastos del día a día repartidos en dos años.
enum DebugSeed {
    #if DEBUG
    static let isActive = UserDefaults.standard.bool(forKey: "DebugSeed")
    #else
    static let isActive = false
    #endif
}

#if DEBUG
extension DebugSeed {
    static let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let email = "debug@pennynote.local"
    // Preferencias aparte de las del App Group: elegir moneda aquí no debe quedar pendiente de subir a
    // la cuenta real. El widget sigue usando la moneda de la instalación de verdad. Se vacían en cada
    // arranque, como el almacén.
    static let defaults: UserDefaults = {
        let defaults = UserDefaults(suiteName: defaultsSuiteName) ?? .standard
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        return defaults
    }()

    private static let defaultsSuiteName = "DebugSeed"

    private static let storeName = "DebugSeed"
    private static let defaultMonthCount = 6
    private static let countedMonthCount = 24

    // Gastos del día a día: índice de categoría en SeedDataService.defaultCategories, título e
    // importe en céntimos. Los repetidos salen más a menudo.
    private static let dailyTemplates: [(category: Int, title: LocalizedStringResource, cents: ClosedRange<Int>)] = [
        (0, "Mercadona", 2500...8000), (0, "Mercadona", 2500...8000), (0, "Café", 150...400),
        (0, "Café", 150...400), (0, "Menú del día", 1100...1600), (0, "Panadería", 200...600),
        (0, "Cena fuera", 2500...5500), (1, "Metro", 150...250), (1, "Gasolina", 4000...7000),
        (1, "Taxi", 800...2000), (2, "Cine", 800...1200), (2, "Concierto", 3000...6000),
        (3, "Ferretería", 1000...3000), (4, "Farmacia", 500...2500), (5, "Ropa", 2000...7000),
        (5, "Amazon", 1000...5000), (5, "Libros", 1200...2500), (6, "Peluquería", 1500...2500),
    ]

    // Gastos fijos de cada mes: categoría, título, importe en céntimos, día del mes y método de pago.
    private static let monthlyTemplates: [(category: Int, title: LocalizedStringResource, cents: ClosedRange<Int>, day: Int, payment: PaymentMethod)] = [
        (3, "Internet", 3500...3500, 2, .transfer),
        (3, "Luz", 4500...8000, 4, .transfer),
        (4, "Gimnasio", 3990...3990, 2, .card),
        (2, "Netflix", 1399...1399, 5, .card),
    ]

    static var dailyExpenseCount: Int? {
        let count = UserDefaults.standard.integer(forKey: "DebugSeedExpenses")
        return count > 0 ? count : nil
    }

    static func makeContainer(schema: Schema, groupContainer: ModelConfiguration.GroupContainer) -> ModelContainer {
        let configuration = ModelConfiguration(storeName, schema: schema, groupContainer: groupContainer)
        // Se borra el almacén anterior para que cada arranque parta de los mismos datos.
        let storeURL = configuration.url
        for suffix in ["", "-shm", "-wal"] {
            let url = storeURL.deletingLastPathComponent().appending(path: storeURL.lastPathComponent + suffix)
            try? FileManager.default.removeItem(at: url)
        }
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("No se pudo crear el ModelContainer de DebugSeed: \(error)")
        }
        // Un contexto propio y no el principal: este contenedor puede crearse fuera del hilo principal.
        let context = ModelContext(container)
        populate(context, dailyExpenseCount: dailyExpenseCount)
        context.saveOrLog(failureMessage: "Fallo al guardar los datos de DebugSeed")
        return container
    }

    // Sin `dailyExpenseCount`, de cero a dos gastos al día durante seis meses. Con semilla fija: salen
    // los mismos datos cada vez, salvo por la fecha de hoy.
    static func populate(_ context: ModelContext, dailyExpenseCount: Int? = nil, now: Date = .now) {
        SeedDataService.seedIfNeeded(context: context)
        let categories = context.categories(failureMessage: "Fallo al leer las categorías de DebugSeed")
        guard categories.count == SeedDataService.defaultCategories.count else { return }

        var generator = SeededGenerator(seed: 42)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let monthCount = dailyExpenseCount == nil ? defaultMonthCount : countedMonthCount
        guard let firstMonth = calendar.date(byAdding: .month, value: -(monthCount - 1), to: calendar.startOfMonth(for: now)) else { return }

        func addExpense(_ category: Int, _ title: LocalizedStringResource, _ cents: ClosedRange<Int>, on date: Date, payment: PaymentMethod) {
            let amount = Decimal(Int.random(in: cents, using: &generator)) / 100
            context.insert(Expense(amount: amount, date: date, title: String(localized: title), paymentMethod: payment, category: categories[category]))
        }

        // Con un número fijo de gastos no se descarta ninguno: los de más tarde de hoy quedan en este momento.
        func addDailyExpense(on day: Date, keepingLaterToday: Bool) {
            let template = dailyTemplates.randomElement(using: &generator)!
            let minutes = Int.random(in: (8 * 60)...(21 * 60), using: &generator)
            let payment: PaymentMethod = Int.random(in: 0..<4, using: &generator) == 0 ? .cash : .card
            guard let date = calendar.date(byAdding: .minute, value: minutes, to: day) else { return }
            guard keepingLaterToday || date <= now else { return }
            addExpense(template.category, template.title, template.cents, on: min(date, now), payment: payment)
        }

        for monthOffset in 0..<monthCount {
            guard let month = calendar.date(byAdding: .month, value: monthOffset, to: firstMonth) else { continue }
            for fixed in monthlyTemplates {
                guard
                    let date = calendar.date(byAdding: DateComponents(day: fixed.day - 1, hour: 10), to: month),
                    date <= now
                else { continue }
                addExpense(fixed.category, fixed.title, fixed.cents, on: date, payment: fixed.payment)
            }
        }

        if let dailyExpenseCount {
            let dayCount = (calendar.dateComponents([.day], from: firstMonth, to: today).day ?? 0) + 1
            for _ in 0..<dailyExpenseCount {
                guard let day = calendar.date(byAdding: .day, value: Int.random(in: 0..<dayCount, using: &generator), to: firstMonth) else { continue }
                addDailyExpense(on: day, keepingLaterToday: true)
            }
            return
        }

        var day = firstMonth
        while day <= today {
            for _ in 0..<Int.random(in: 0...2, using: &generator) {
                addDailyExpense(on: day, keepingLaterToday: false)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
    }
}

// SplitMix64: generador con semilla, porque el de Swift no se puede sembrar.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
#endif
