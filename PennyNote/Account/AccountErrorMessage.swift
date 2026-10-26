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
            return "El servidor ha rechazado los datos. Inténtalo de nuevo más tarde."
        }
        return "No se ha podido completar la operación. Inténtalo de nuevo."
    }

    private static func accountMessage(for error: AccountError) -> String {
        switch error {
        case .notConfigured:
            "Esta versión de la app no tiene configurado el servidor."
        case .emailConfirmationRequired:
            "Cuenta creada, pero el servidor pide confirmar el email y no envía correos. Avisa a quien administra PennyNote."
        }
    }

    private static func networkMessage(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            "No hay conexión a internet."
        case .timedOut:
            "El servidor no responde. Inténtalo de nuevo en un momento."
        default:
            "No se ha podido conectar con el servidor."
        }
    }

    private static func authMessage(for error: AuthError) -> String {
        // Solo el código (sin el texto del servidor, que puede incluir el email): basta para saber la causa
        // cuando la app enseña el mensaje genérico.
        Log.auth.error("Error de Supabase Auth: \(error.errorCode.rawValue, privacy: .public)")
        return switch error.errorCode {
        case .invalidCredentials:
            "Email o contraseña incorrectos."
        case .emailExists, .userAlreadyExists:
            "Ya hay una cuenta con ese email. Inicia sesión."
        case .weakPassword:
            "La contraseña es demasiado débil. Usa al menos \(PasswordRules.minimumLength) caracteres."
        case .samePassword:
            "La nueva contraseña tiene que ser distinta de la anterior."
        case .reauthenticationNeeded:
            // Solo si el proyecto tiene activado «Secure password change», que pide un código por email.
            "No se puede cambiar la contraseña sin volver a verificar la cuenta."
        case .overRequestRateLimit:
            "Demasiados intentos. Espera unos minutos y vuelve a probar."
        case .overEmailSendRateLimit:
            // La app no envía correos: solo pasa si el proyecto de Supabase tiene activado algún envío
            // (Confirm email o Secure password change).
            "El servidor ha intentado enviar un email y ha llegado a su límite. Avisa a quien administra PennyNote."
        case .validationFailed:
            "Revisa el email: no parece válido."
        case .emailNotConfirmed:
            // Solo pasa si el proyecto de Supabase tiene activada la confirmación de email.
            "El servidor pide confirmar el email y no envía correos. Avisa a quien administra PennyNote."
        case .signupDisabled:
            "No se pueden crear cuentas nuevas ahora mismo."
        case .sessionNotFound, .sessionExpired, .refreshTokenNotFound, .refreshTokenAlreadyUsed:
            "La sesión ha caducado. Vuelve a iniciar sesión."
        default:
            "No se ha podido completar la operación. Inténtalo de nuevo."
        }
    }
}

enum PasswordRules {
    static let minimumLength = 8

    static func isValid(_ password: String) -> Bool {
        password.count >= minimumLength
    }
}
