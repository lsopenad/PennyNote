import Foundation

// Cuánto puede estar la app en segundo plano sin volver a pedir Face ID. El valor es en segundos y es
// lo que se guarda.
enum AppLockTimeout: Int, CaseIterable, Identifiable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900

    var id: Self { self }

    var seconds: TimeInterval {
        TimeInterval(rawValue)
    }

    var title: LocalizedStringResource {
        switch self {
        case .immediately: "Inmediatamente"
        case .oneMinute: "Tras 1 minuto"
        case .fiveMinutes: "Tras 5 minutos"
        case .fifteenMinutes: "Tras 15 minutos"
        }
    }
}
