import Foundation

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash = "Efectivo"
    case card = "Tarjeta"
    case transfer = "Transferencia"
    case other = "Otro"

    var id: String { rawValue }
}
