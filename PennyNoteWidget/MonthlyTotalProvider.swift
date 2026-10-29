import WidgetKit
import Foundation

struct MonthlyTotalProvider: TimelineProvider {
    // Las recargas las dispara la propia app tras cada cambio. Además se deja una entrada por cada
    // medianoche de esta semana, para que el día de hoy avance en las barras y el mes cambie a cero
    // el día 1 aunque la app no se abra.
    private static let upcomingMidnightCount = 7

    func placeholder(in context: Context) -> MonthlyTotalEntry {
        let calendar = Calendar.current
        let monthStart = calendar.startOfMonth(for: .now)
        let previousStart = calendar.startOfPreviousMonth(for: monthStart) ?? monthStart
        let sample: [Decimal] = [12, 0, 30, 4, 18, 0, 55, 8, 20, 0, 3, 14, 6, 0, 9, 22, 5, 0, 11, 7, 0, 16, 4, 0, 25, 3, 8, 0, 12, 6, 2]
        let snapshot = WidgetSnapshot(
            current: MonthSpending(monthStart: monthStart, dailyTotals: Array(sample.prefix(MonthSpending.empty(monthStart: monthStart).dailyTotals.count))),
            previous: MonthSpending(monthStart: previousStart, dailyTotals: Array(repeating: 12, count: 31)),
            topCategories: [
                .init(name: "Comida", symbolName: "fork.knife", colorName: CategoryColor.blue.rawValue, total: 182.4),
                .init(name: "Transporte", symbolName: "car.fill", colorName: CategoryColor.orange.rawValue, total: 64),
                .init(name: "Ocio", symbolName: "gamecontroller.fill", colorName: CategoryColor.green.rawValue, total: 38.5),
            ]
        )
        return MonthlyTotalEntry(date: .now, display: WidgetDisplay(snapshot: snapshot, at: .now), currency: Self.currency)
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthlyTotalEntry) -> Void) {
        let snapshot = WidgetSnapshotStore.read()
        completion(MonthlyTotalEntry(date: .now, display: WidgetDisplay(snapshot: snapshot, at: .now), currency: Self.currency))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthlyTotalEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.read()
        let currency = Self.currency
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let midnights = (1...Self.upcomingMidnightCount).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let entries = ([Date.now] + midnights).map { date in
            MonthlyTotalEntry(date: date, display: WidgetDisplay(snapshot: snapshot, at: date, calendar: calendar), currency: currency)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    // La que ha guardado la app; sin sesión, la de la región, como en la app.
    private static var currency: AppCurrency {
        AppCurrency.stored() ?? .regionDefault()
    }
}
