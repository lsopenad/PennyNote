import SwiftUI

struct MonthHeaderView: View {
    let total: Decimal

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: .now).capitalized
    }

    private var totalLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: total as NSDecimalNumber) ?? "\(total) €"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monthLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(totalLabel)
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
