import WidgetKit
import Foundation

struct MonthlyTotalProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthlyTotalEntry {
        MonthlyTotalEntry(date: .now, total: 42.50, monthLabel: monthLabel(for: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthlyTotalEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthlyTotalEntry>) -> Void) {
        // Las recargas las dispara la propia app tras cada cambio; este refresco es solo
        // una red de seguridad para no quedar nunca completamente obsoleto.
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
        let timeline = Timeline(entries: [currentEntry()], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func currentEntry() -> MonthlyTotalEntry {
        if let stored = MonthlyTotalStore.read() {
            return MonthlyTotalEntry(date: .now, total: stored.total, monthLabel: monthLabel(for: stored.monthStart))
        }
        return MonthlyTotalEntry(date: .now, total: .zero, monthLabel: monthLabel(for: .now))
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date).capitalized
    }
}
