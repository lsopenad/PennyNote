import SwiftUI

// Fila de reparto (categoría o método de pago): icono, nombre, importe, porcentaje y una barra
// proporcional a su parte del total.
struct SpendingShareRow: View {
    let title: String
    let symbolName: String
    let color: Color
    let total: Decimal
    // Parte del total del mes, de 0 a 1.
    let fraction: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .lineLimit(1)
                    Spacer()
                    Text(DisplayFormat.currency(total))
                        .monospacedDigit()
                    Text(DisplayFormat.percent(fraction))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 40, alignment: .trailing)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.fill.tertiary)
                        Capsule()
                            .fill(color)
                            .frame(width: geometry.size.width * min(max(fraction, 0), 1))
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        SpendingShareRow(title: "Comida", symbolName: "fork.knife", color: .orange, total: 182.4, fraction: 0.42)
        SpendingShareRow(title: "Transporte", symbolName: "car.fill", color: .blue, total: 60, fraction: 0.14)
    }
}
