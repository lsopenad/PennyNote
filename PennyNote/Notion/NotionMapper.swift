import Foundation

// Traduce entre nuestros campos de dominio y la forma de JSON de propiedades que exige Notion.
// Se usa [String: Any] en vez de Codable estricto porque el JSON de "properties" de Notion
// tiene una forma muy heterogénea según el tipo de cada propiedad (title/number/date/select).
enum NotionMapper {
    static func properties(
        amount: Decimal,
        date: Date,
        title: String,
        paymentMethod: PaymentMethod,
        categoryName: String?
    ) -> [String: Any] {
        var properties: [String: Any] = [
            NotionPropertyName.title: [
                "title": [["text": ["content": title.isEmpty ? "Gasto" : title]]]
            ],
            NotionPropertyName.amount: [
                "number": NSDecimalNumber(decimal: amount).doubleValue
            ],
            NotionPropertyName.date: [
                "date": ["start": isoDateOnly(date)]
            ],
            NotionPropertyName.paymentMethod: [
                "select": ["name": paymentMethod.rawValue]
            ],
        ]
        if let categoryName {
            properties[NotionPropertyName.category] = ["select": ["name": categoryName]]
        }
        return properties
    }

    static func databaseSchemaProperties(categoryNames: [String]) -> [String: Any] {
        [
            NotionPropertyName.title: ["title": [String: Any]()],
            NotionPropertyName.amount: ["number": ["format": "euro"]],
            NotionPropertyName.date: ["date": [String: Any]()],
            NotionPropertyName.category: [
                "select": ["options": categoryNames.map { ["name": $0] }]
            ],
            NotionPropertyName.paymentMethod: [
                "select": ["options": PaymentMethod.allCases.map { ["name": $0.rawValue] }]
            ],
        ]
    }

    // También se usa para sanar el esquema de bases de datos ya conectadas antes de que
    // existiera el campo Método de pago (se llama en cada sync, ver SyncEngine).
    static func categorySchemaProperties(categoryNames: [String]) -> [String: Any] {
        [
            NotionPropertyName.category: [
                "select": ["options": categoryNames.map { ["name": $0] }]
            ],
            NotionPropertyName.paymentMethod: [
                "select": ["options": PaymentMethod.allCases.map { ["name": $0.rawValue] }]
            ],
        ]
    }

    static func parsePage(_ json: [String: Any]) -> ParsedNotionPage? {
        guard
            let id = json["id"] as? String,
            let lastEditedString = json["last_edited_time"] as? String,
            let lastEditedTime = parseISODate(lastEditedString),
            let properties = json["properties"] as? [String: Any]
        else { return nil }

        let archived = json["archived"] as? Bool ?? false

        var title = ""
        if let titleProp = properties[NotionPropertyName.title] as? [String: Any],
           let titleArray = titleProp["title"] as? [[String: Any]],
           let first = titleArray.first,
           let text = first["plain_text"] as? String {
            title = text
        }

        var amount: Decimal = 0
        if let amountProp = properties[NotionPropertyName.amount] as? [String: Any],
           let number = amountProp["number"] as? Double {
            // Nunca Decimal(double) directo: se convierte vía texto para evitar artefactos binarios
            // (p. ej. 19.99 → 19.989999999999998) que se colarían en el modelo local en cada pull.
            amount = Decimal(string: String(format: "%.2f", number)) ?? Decimal(number)
        }

        var date = Date.now
        if let dateProp = properties[NotionPropertyName.date] as? [String: Any],
           let dateWrapper = dateProp["date"] as? [String: Any],
           let start = dateWrapper["start"] as? String {
            date = dateOnlyFormatter.date(from: start) ?? parseISODate(start) ?? .now
        }

        var categoryName: String?
        var categorySelectID: String?
        if let categoryProp = properties[NotionPropertyName.category] as? [String: Any],
           let select = categoryProp["select"] as? [String: Any] {
            categoryName = select["name"] as? String
            categorySelectID = select["id"] as? String
        }

        var paymentMethod = PaymentMethod.card
        if let paymentProp = properties[NotionPropertyName.paymentMethod] as? [String: Any],
           let select = paymentProp["select"] as? [String: Any],
           let name = select["name"] as? String,
           let matched = PaymentMethod(rawValue: name) {
            paymentMethod = matched
        }

        return ParsedNotionPage(
            id: id,
            lastEditedTime: lastEditedTime,
            archived: archived,
            amount: amount,
            date: date,
            title: title,
            paymentMethod: paymentMethod,
            categoryName: categoryName,
            categorySelectID: categorySelectID
        )
    }

    static func parseISODate(_ string: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    static func isoDateTime(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func isoDateOnly(_ date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
