import SwiftUI

struct MonthHeaderView: View {
    let total: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DisplayFormat.monthName(.now))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(DisplayFormat.currency(total))
                .font(.system(size: 40, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

#Preview {
    MonthHeaderView(total: 123.45)
}
