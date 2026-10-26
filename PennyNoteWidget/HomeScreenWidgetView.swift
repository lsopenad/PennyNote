import SwiftUI

struct HomeScreenWidgetView: View {
    let entry: MonthlyTotalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.monthLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(DisplayFormat.currency(entry.total))
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
