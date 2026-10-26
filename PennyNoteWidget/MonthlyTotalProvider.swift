import WidgetKit
import Foundation

struct MonthlyTotalProvider: TimelineProvider {
    // Las recargas las dispara la propia app tras cada cambio; este refresco es solo
    // una red de seguridad para no quedar nunca completamente obsoleto.
    private static let fallbackRefreshHours = 6

    func placeholder(in context: Context) -> MonthlyTotalEntry {
        MonthlyTotalEntry(date: .now, total: 42.50, monthLabel: DisplayFormat.monthName(.now))
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthlyTotalEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthlyTotalEntry>) -> Void) {
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: Self.fallbackRefreshHours, to: .now) ?? .now
        let timeline = Timeline(entries: [currentEntry()], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func currentEntry() -> MonthlyTotalEntry {
        if let stored = MonthlyTotalStore.read() {
            return MonthlyTotalEntry(date: .now, total: stored.total, monthLabel: DisplayFormat.monthName(stored.monthStart))
        }
        return MonthlyTotalEntry(date: .now, total: .zero, monthLabel: DisplayFormat.monthName(.now))
    }
}
