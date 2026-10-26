import Foundation

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash = "Efectivo"
    case card = "Tarjeta"
    case transfer = "Transferencia"
    case other = "Otro"

    var id: String { rawValue }

    // Código estable con el que se guarda en el servidor, independiente del texto que se muestra.
    var serverCode: String {
        switch self {
        case .cash: "cash"
        case .card: "card"
        case .transfer: "transfer"
        case .other: "other"
        }
    }

    init?(serverCode: String) {
        guard let method = Self.allCases.first(where: { $0.serverCode == serverCode }) else { return nil }
        self = method
    }

    var symbolName: String {
        switch self {
        case .cash: "banknote"
        case .card: "creditcard"
        case .transfer: "arrow.left.arrow.right"
        case .other: "ellipsis.circle"
        }
    }
}
