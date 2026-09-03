import Foundation

// Página de Notion ya interpretada a nuestros campos de dominio (ver NotionMapper).
struct ParsedNotionPage {
    let id: String
    let lastEditedTime: Date
    let archived: Bool
    let amount: Decimal
    let date: Date
    let title: String
    let paymentMethod: PaymentMethod
    let categoryName: String?
    let categorySelectID: String?
}

enum NotionPropertyName {
    // Es la propiedad de tipo "title" de Notion (obligatoria en toda página): aquí vive nuestro
    // campo de dominio "título" del gasto, no un campo separado.
    static let title = "Nota"
    static let amount = "Cantidad"
    static let date = "Fecha"
    static let category = "Categoría"
    static let paymentMethod = "Método de pago"
}
