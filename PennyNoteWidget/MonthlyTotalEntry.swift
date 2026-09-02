import WidgetKit
import Foundation

struct MonthlyTotalEntry: TimelineEntry {
    let date: Date
    let total: Decimal
    let monthLabel: String
}
