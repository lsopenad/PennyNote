import Foundation

// Cómo se puede desbloquear la app en este iPhone.
enum DeviceAuthMethod: Equatable {
    case faceID
    case touchID
    // Sin biometría configurada: solo el código del iPhone.
    case passcode
    // El iPhone no tiene código: no hay con qué autenticarse.
    case none
}

enum DeviceAuthResult: Equatable {
    case success
    // Cancelado o fallido.
    case failure
    // El iPhone no tiene código.
    case unavailable
}

// Separado de LocalAuthentication para poder probar AppLock sin Face ID.
@MainActor
protocol DeviceAuthenticator {
    func availableMethod() -> DeviceAuthMethod
    func authenticate(reason: String) async -> DeviceAuthResult
}
