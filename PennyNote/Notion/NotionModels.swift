import Foundation

// Página de Notion ya interpretada a nuestros campos de dominio (ver NotionMapper).
struct ParsedNotionPage {
    let id: String
    let lastEditedTime: Date
    let archived: Bool
    let amount: Decimal
    let date: Date
    let note: String
    let categoryName: String?
    let categorySelectID: String?
}

enum NotionPropertyName {
    static let note = "Nota"
    static let amount = "Cantidad"
    static let date = "Fecha"
    static let category = "Categoría"
}
