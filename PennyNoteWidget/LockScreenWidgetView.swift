import SwiftUI
import WidgetKit

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MonthlyTotalEntry

    private var totalLabel: String {
        DisplayFormat.currency(entry.total, showsCents: false)
    }

    var body: some View {
        content
            .containerBackground(for: .widget) { Color.clear }
    }

    // La pantalla de bloqueo fuerza monocromía: no depender de color para transmitir información.
    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "eurosign.circle")
                    .font(.caption2)
                Text(totalLabel)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        default:
            HStack {
                Image(systemName: "eurosign.circle")
                VStack(alignment: .leading, spacing: 0) {
                    Text("Este mes")
                        .font(.caption2)
                    Text(totalLabel)
                        .font(.headline)
                }
            }
        }
    }
}
