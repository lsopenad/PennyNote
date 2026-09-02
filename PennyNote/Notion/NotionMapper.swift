import Foundation

// Traduce entre nuestros campos de dominio y la forma de JSON de propiedades que exige Notion.
// Se usa [String: Any] en vez de Codable estricto porque el JSON de "properties" de Notion
// tiene una forma muy heterogénea según el tipo de cada propiedad (title/number/date/select).
enum NotionMapper {
    static func properties(amount: Decimal, date: Date, note: String, categoryName: String?) -> [String: Any] {
        var properties: [String: Any] = [
            NotionPropertyName.note: [
                "title": [["text": ["content": note.isEmpty ? "Gasto" : note]]]
            ],
            NotionPropertyName.amount: [
                "number": NSDecimalNumber(decimal: amount).doubleValue
            ],
            NotionPropertyName.date: [
                "date": ["start": isoDateOnly(date)]
            ],
        ]
        if let categoryName {
            properties[NotionPropertyName.category] = ["select": ["name": categoryName]]
        }
        return properties
    }

    static func databaseSchemaProperties(categoryNames: [String]) -> [String: Any] {
        [
            NotionPropertyName.note: ["title": [String: Any]()],
            NotionPropertyName.amount: ["number": ["format": "euro"]],
            NotionPropertyName.date: ["date": [String: Any]()],
            NotionPropertyName.category: [
                "select": ["options": categoryNames.map { ["name": $0] }]
            ],
        ]
    }

    static func categorySchemaProperties(categoryNames: [String]) -> [String: Any] {
        [
            NotionPropertyName.category: [
                "select": ["options": categoryNames.map { ["name": $0] }]
            ]
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

        var note = ""
        if let noteProp = properties[NotionPropertyName.note] as? [String: Any],
           let titleArray = noteProp["title"] as? [[String: Any]],
           let first = titleArray.first,
           let text = first["plain_text"] as? String {
            note = text
        }

        var amount: Decimal = 0
        if let amountProp = properties[NotionPropertyName.amount] as? [String: Any],
           let number = amountProp["number"] as? Double {
            amount = Decimal(number)
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

        return ParsedNotionPage(
            id: id,
            lastEditedTime: lastEditedTime,
            archived: archived,
            amount: amount,
            date: date,
            note: note,
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
