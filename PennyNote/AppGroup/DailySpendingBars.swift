import SwiftUI

// Minigráfica de una barra fina por día del mes, sin ejes. La comparten la cabecera de la app y
// el widget; por eso son formas simples y no Swift Charts, que aquí solo añadiría peso.
struct DailySpendingBars: View {
    let dailyTotals: [Decimal]
    // Días ya empezados (incluido hoy). Los posteriores sin gasto se pintan como huecos grises.
    let elapsedDays: Int
    // Día que se resalta (hoy); nil para no resaltar ninguno.
    var highlightedDay: Int?
    var color: Color = .brand

    private let stubHeight: CGFloat = 2

    var body: some View {
        let values = dailyTotals.map(\.doubleValue)
        let maxValue = values.max() ?? 0

        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: barSpacing(for: geometry.size.width)) {
                ForEach(values.indices, id: \.self) { index in
                    let day = index + 1
                    let ratio = maxValue > 0 ? values[index] / maxValue : 0
                    Capsule()
                        .fill(fill(day: day, hasSpending: values[index] > 0))
                        .frame(height: max(stubHeight, geometry.size.height * ratio))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gasto diario del mes")
    }

    private func fill(day: Int, hasSpending: Bool) -> AnyShapeStyle {
        // Un gasto con fecha futura se dibuja igualmente: cuenta en el total que hay encima.
        if !hasSpending {
            return AnyShapeStyle(day > elapsedDays ? .quaternary : .tertiary)
        }
        return AnyShapeStyle(color.opacity(day == highlightedDay ? 1 : 0.55))
    }

    // Con 31 barras en un widget pequeño no caben 2 pt de separación sin que desaparezcan las barras.
    private func barSpacing(for width: CGFloat) -> CGFloat {
        width / CGFloat(max(dailyTotals.count, 1)) > 6 ? 2 : 1
    }
}

#Preview {
    DailySpendingBars(
        dailyTotals: [12, 0, 30, 4, 0, 0, 55, 8, 20, 0, 3, 14, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        elapsedDays: 16,
        highlightedDay: 16
    )
    .frame(height: 32)
    .padding()
}
