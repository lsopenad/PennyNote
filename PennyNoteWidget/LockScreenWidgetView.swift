import SwiftUI
import WidgetKit

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MonthlyTotalEntry

    private var totalLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "es_ES")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: entry.total as NSDecimalNumber) ?? "\(entry.total) €"
    }

    var body: some View {
        // La pantalla de bloqueo fuerza monocromía: no depender de color para transmitir información.
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
            .containerBackground(for: .widget) { Color.clear }
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
            .containerBackground(for: .widget) { Color.clear }
        }
    }
}
