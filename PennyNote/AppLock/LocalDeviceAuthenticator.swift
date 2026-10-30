import LocalAuthentication

// Face ID o Touch ID y, si fallan o no están configurados, el código del iPhone
// (.deviceOwnerAuthentication): así nunca se queda nadie fuera de sus datos.
struct LocalDeviceAuthenticator: DeviceAuthenticator {
    func availableMethod() -> DeviceAuthMethod {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return .none }
        // biometryType solo es fiable tras preguntar por la política de biometría.
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return .passcode }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .passcode
        }
    }

    func authenticate(reason: String) async -> DeviceAuthResult {
        do {
            return try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) ? .success : .failure
        } catch let error as LAError {
            switch error.code {
            case .passcodeNotSet:
                return .unavailable
            case .userCancel, .appCancel, .systemCancel, .authenticationFailed:
                return .failure
            default:
                Log.auth.error("Fallo inesperado al pedir Face ID: \(error.localizedDescription)")
                return .failure
            }
        } catch {
            Log.auth.error("Fallo inesperado al pedir Face ID: \(error.localizedDescription)")
            return .failure
        }
    }
}
