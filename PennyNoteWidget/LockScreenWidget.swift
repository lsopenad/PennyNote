import WidgetKit
import SwiftUI

struct LockScreenWidget: Widget {
    let kind = "LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonthlyTotalProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .widgetURL(URL(string: "pennynote://add"))
        }
        .configurationDisplayName("Gasto del mes")
        .description("Total gastado este mes en la pantalla de bloqueo.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
