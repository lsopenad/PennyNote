import Foundation

// Cada cuánto se repite un gasto recurrente. El rawValue es el código con el que se guarda, en el
// móvil y en el servidor.
enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    // «Cada mes», para el selector «Repetir» y la lista de recurrentes.
    var title: LocalizedStringResource {
        switch self {
        case .weekly: "Cada semana"
        case .monthly: "Cada mes"
        case .yearly: "Cada año"
        }
    }

    var serverCode: String { rawValue }

    init?(serverCode: String) {
        self.init(rawValue: serverCode)
    }

    // Unidad que se suma a la fecha de inicio para obtener cada repetición.
    var component: Calendar.Component {
        switch self {
        case .weekly: .weekOfYear
        case .monthly: .month
        case .yearly: .year
        }
    }
}
