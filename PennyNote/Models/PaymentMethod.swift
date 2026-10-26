import Foundation

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash = "Efectivo"
    case card = "Tarjeta"
    case transfer = "Transferencia"
    case other = "Otro"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .cash: "banknote"
        case .card: "creditcard"
        case .transfer: "arrow.left.arrow.right"
        case .other: "ellipsis.circle"
        }
    }
}
