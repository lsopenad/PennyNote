import Foundation

// El rawValue es el código estable con el que se guarda, en el móvil y en el servidor; el texto
// que se muestra es `title`, en el idioma del móvil.
enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash
    case card
    case transfer
    case other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .cash: "Efectivo"
        case .card: "Tarjeta"
        case .transfer: "Transferencia"
        case .other: "Otro"
        }
    }

    // Código con el que se guarda en el servidor; el mismo que en el móvil desde el esquema V2.
    var serverCode: String { rawValue }

    init?(serverCode: String) {
        self.init(rawValue: serverCode)
    }

    // Lo que guardaban las versiones anteriores a la 1.3.0 (el texto en español), para migrarlo.
    init?(legacyName: String) {
        switch legacyName {
        case "Efectivo": self = .cash
        case "Tarjeta": self = .card
        case "Transferencia": self = .transfer
        case "Otro": self = .other
        default: return nil
        }
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
