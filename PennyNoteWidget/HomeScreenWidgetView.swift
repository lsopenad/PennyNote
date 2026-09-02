import SwiftUI

struct HomeScreenWidgetView: View {
    let entry: MonthlyTotalEntry

    private var totalLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: entry.total as NSDecimalNumber) ?? "\(entry.total) €"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.monthLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(totalLabel)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("Este mes")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}
