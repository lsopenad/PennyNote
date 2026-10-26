import Foundation
import SwiftData

// Datos del modo demo: un almacén en memoria, aparte del compartido, con las categorías de serie y
// unos seis meses de gastos inventados. No se sincroniza ni llega al widget, y desaparece al salir.
@MainActor
enum DemoData {
    private static let monthCount = 6

    // Gastos del día a día: índice de categoría en SeedDataService.defaultCategories, título e
    // importe en céntimos. Los repetidos salen más a menudo.
    private static let dailyTemplates: [(category: Int, title: String, cents: ClosedRange<Int>)] = [
        (0, "Mercadona", 2500...8000), (0, "Mercadona", 2500...8000), (0, "Café", 150...400),
        (0, "Café", 150...400), (0, "Menú del día", 1100...1600), (0, "Panadería", 200...600),
        (0, "Cena fuera", 2500...5500), (1, "Metro", 150...250), (1, "Gasolina", 4000...7000),
        (1, "Taxi", 800...2000), (2, "Cine", 800...1200), (2, "Concierto", 3000...6000),
        (3, "Ferretería", 1000...3000), (4, "Farmacia", 500...2500), (5, "Ropa", 2000...7000),
        (5, "Amazon", 1000...5000), (5, "Libros", 1200...2500), (6, "Peluquería", 1500...2500),
    ]

    // Gastos fijos de cada mes: categoría, título, importe en céntimos, día del mes y método de pago.
    private static let monthlyTemplates: [(category: Int, title: String, cents: ClosedRange<Int>, day: Int, payment: PaymentMethod)] = [
        (3, "Internet", 3500...3500, 2, .transfer),
        (3, "Luz", 4500...8000, 4, .transfer),
        (4, "Gimnasio", 3990...3990, 2, .card),
        (2, "Netflix", 1399...1399, 5, .card),
    ]

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Expense.self, ExpenseCategory.self])
        let configuration = ModelConfiguration("Demo", schema: schema, isStoredInMemoryOnly: true)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("No se pudo crear el ModelContainer en memoria de la demo: \(error)")
        }
        populate(container.mainContext)
        return container
    }

    private static func populate(_ context: ModelContext) {
        SeedDataService.seedIfNeeded(context: context)
        let categories = context.categories(failureMessage: "Fallo al leer las categorías de la demo")
        guard categories.count == SeedDataService.defaultCategories.count else { return }

        // Semilla fija: la demo sale igual cada vez, salvo por la fecha de hoy.
        var generator = SeededGenerator(seed: 42)
        let now = Date.now
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let firstMonth = calendar.date(byAdding: .month, value: -(monthCount - 1), to: calendar.startOfMonth(for: now)) else { return }

        func addExpense(_ category: Int, _ title: String, _ cents: ClosedRange<Int>, on date: Date, payment: PaymentMethod) {
            guard date <= now else { return }
            let amount = Decimal(Int.random(in: cents, using: &generator)) / 100
            context.insert(Expense(amount: amount, date: date, title: title, paymentMethod: payment, category: categories[category]))
        }

        for monthOffset in 0..<monthCount {
            guard let month = calendar.date(byAdding: .month, value: monthOffset, to: firstMonth) else { continue }
            for fixed in monthlyTemplates {
                guard let date = calendar.date(byAdding: DateComponents(day: fixed.day - 1, hour: 10), to: month) else { continue }
                addExpense(fixed.category, fixed.title, fixed.cents, on: date, payment: fixed.payment)
            }
        }

        var day = firstMonth
        while day <= today {
            for _ in 0..<Int.random(in: 0...2, using: &generator) {
                let template = dailyTemplates.randomElement(using: &generator)!
                let minutes = Int.random(in: (8 * 60)...(21 * 60), using: &generator)
                let payment: PaymentMethod = Int.random(in: 0..<4, using: &generator) == 0 ? .cash : .card
                if let date = calendar.date(byAdding: .minute, value: minutes, to: day) {
                    addExpense(template.category, template.title, template.cents, on: date, payment: payment)
                }
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
