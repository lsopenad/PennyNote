import WidgetKit
import SwiftUI

struct HomeScreenWidget: Widget {
    let kind = "HomeScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonthlyTotalProvider()) { entry in
            HomeScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Gasto del mes")
        .description("Muestra el gasto del mes y cómo va respecto al anterior.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
