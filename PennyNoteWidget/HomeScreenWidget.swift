import WidgetKit
import SwiftUI

struct HomeScreenWidget: Widget {
    let kind = "HomeScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonthlyTotalProvider()) { entry in
            HomeScreenWidgetView(entry: entry)
                .widgetURL(URL(string: "pennynote://add"))
        }
        .configurationDisplayName("Gasto del mes")
        .description("Muestra el total gastado este mes.")
        .supportedFamilies([.systemSmall])
    }
}
