import WidgetKit
import Foundation

struct MonthlyTotalEntry: TimelineEntry {
    let date: Date
    let display: WidgetDisplay

    var total: Decimal { display.current.total }
    var monthLabel: String { DisplayFormat.monthName(display.current.monthStart) }
}
