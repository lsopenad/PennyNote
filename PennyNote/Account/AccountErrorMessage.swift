import Foundation
import Supabase
import os

// Traduce los errores de Supabase y de red a un mensaje que se pueda enseñar al usuario.
enum AccountErrorMessage {
    static func message(for error: Error) -> String {
        if let accountError = error as? AccountError {
            return accountMessage(for: accountError)
        }
        if let urlError = error as? URLError {
            return networkMessage(for: urlError)
        }
        if let authError = error as? AuthError {
            return authMessage(for: authError)
        }
        if error is PostgrestError {
            return String(localized: "El servidor ha rechazado los datos. Inténtalo de nuevo más tarde.")
        }
        return String(localized: "No se ha podido completar la operación. Inténtalo de nuevo.")
    }

    private static func accountMessage(for error: AccountError) -> String {
        switch error {
        case .notConfigured:
            String(localized: "Esta versión de la app no tiene configurado el servidor.")
        case .emailConfirmationRequired:
            String(localized: "Cuenta creada, pero el servidor pide confirmar el email y no envía correos. Avisa a quien administra PennyNote.")
        }
    }

    private static func networkMessage(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            String(localized: "No hay conexión a internet.")
        case .timedOut:
            String(localized: "El servidor no responde. Inténtalo de nuevo en un momento.")
        default:
            String(localized: "No se ha podido conectar con el servidor.")
        }
    }

    private static func authMessage(for error: AuthError) -> String {
        // Solo el código (sin el texto del servidor, que puede incluir el email): basta para saber la causa
        // cuando la app enseña el mensaje genérico.
        Log.auth.error("Error de Supabase Auth: \(error.errorCode.rawValue, privacy: .public)")
        return switch error.errorCode {
        case .invalidCredentials:
            String(localized: "Email o contraseña incorrectos.")
        case .emailExists, .userAlreadyExists:
            String(localized: "Ya hay una cuenta con ese email. Inicia sesión.")
        case .weakPassword:
            String(localized: "La contraseña es demasiado débil. Usa al menos \(PasswordRules.minimumLength) caracteres.")
        case .samePassword:
            String(localized: "La nueva contraseña tiene que ser distinta de la anterior.")
        case .reauthenticationNeeded:
            // Solo si el proyecto tiene activado «Secure password change», que pide un código por email.
            String(localized: "No se puede cambiar la contraseña sin volver a verificar la cuenta.")
        case .overRequestRateLimit:
            String(localized: "Demasiados intentos. Espera unos minutos y vuelve a probar.")
        case .overEmailSendRateLimit:
            // La app no envía correos: solo pasa si el proyecto de Supabase tiene activado algún envío
            // (Confirm email o Secure password change).
            String(localized: "El servidor ha intentado enviar un email y ha llegado a su límite. Avisa a quien administra PennyNote.")
        case .validationFailed:
            String(localized: "Revisa el email: no parece válido.")
        case .emailNotConfirmed:
            // Solo pasa si el proyecto de Supabase tiene activada la confirmación de email.
            String(localized: "El servidor pide confirmar el email y no envía correos. Avisa a quien administra PennyNote.")
        case .signupDisabled:
            String(localized: "No se pueden crear cuentas nuevas ahora mismo.")
        case .sessionNotFound, .sessionExpired, .refreshTokenNotFound, .refreshTokenAlreadyUsed:
            String(localized: "La sesión ha caducado. Vuelve a iniciar sesión.")
        default:
            String(localized: "No se ha podido completar la operación. Inténtalo de nuevo.")
        }
    }
}

enum PasswordRules {
    static let minimumLength = 8

    static func isValid(_ password: String) -> Bool {
        password.count >= minimumLength
    }
}
