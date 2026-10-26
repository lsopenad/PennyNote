import Foundation

enum NotionError: Error, LocalizedError {
    case notConfigured
    case unauthorized
    case notFound
    case rateLimited(retryAfter: TimeInterval)
    case validation(message: String)
    case network(Error)
    case http(statusCode: Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Notion no está configurado todavía."
        case .unauthorized:
            return "Token de Notion inválido."
        case .notFound:
            return "No se encuentra la página o la base de datos. Comparte la página con la integración desde Notion."
        case .rateLimited:
            return "Notion está limitando las peticiones, reintentando…"
        case .validation(let message):
            return message
        case .network:
            return "Error de red al conectar con Notion."
        case .http(let statusCode):
            return "Notion respondió con un error inesperado (código \(statusCode))."
        case .decoding:
            return "Respuesta inesperada de Notion."
        }
    }
}
