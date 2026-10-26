import Foundation
import os

// Traduce entre nuestros campos de dominio y la forma de JSON de propiedades que exige Notion.
// Se usa [String: Any] en vez de Codable estricto porque el JSON de "properties" de Notion
// tiene una forma muy heterogénea según el tipo de cada propiedad (title/number/date/select).
enum NotionMapper {
    // Notion muestra "Sin título" en las páginas vacías; se prefiere un título reconocible.
    static let fallbackTitle = "Gasto"

    static func properties(for fields: NotionExpenseFields) -> [String: Any] {
        var properties: [String: Any] = [
            NotionPropertyName.title: [
                "title": [["text": ["content": fields.title.isEmpty ? fallbackTitle : fields.title]]]
            ],
            NotionPropertyName.amount: ["number": jsonNumber(fields.amount)],
            NotionPropertyName.date: ["date": ["start": isoDateOnly(fields.date)]],
            NotionPropertyName.paymentMethod: ["select": ["name": fields.paymentMethod.rawValue]],
        ]
        if let categoryName = fields.categoryName {
            properties[NotionPropertyName.category] = ["select": ["name": categoryName]]
        }
        return properties
    }

    static func databaseSchemaProperties(categoryNames: [String]) -> [String: Any] {
        let baseProperties: [String: Any] = [
            NotionPropertyName.title: ["title": [String: Any]()],
            NotionPropertyName.amount: ["number": ["format": "euro"]],
            NotionPropertyName.date: ["date": [String: Any]()],
        ]
        return baseProperties.merging(categorySchemaProperties(categoryNames: categoryNames)) { current, _ in current }
    }

    // También se usa para sanar el esquema de bases de datos ya conectadas antes de que
    // existiera el campo Método de pago (se llama en cada sync, ver SyncEngine).
    static func categorySchemaProperties(categoryNames: [String]) -> [String: Any] {
        [
            NotionPropertyName.category: selectSchema(optionNames: categoryNames),
            NotionPropertyName.paymentMethod: selectSchema(optionNames: PaymentMethod.allCases.map(\.rawValue)),
        ]
    }

    // Los valores que faltan se rellenan con un valor por defecto para no perder la página entera,
    // pero se deja aviso en el log porque el gasto local puede quedar distinto al de Notion.
    static func parsePage(_ json: [String: Any]) -> ParsedNotionPage? {
        guard
            let id = json["id"] as? String,
            let lastEditedString = json["last_edited_time"] as? String,
            let lastEditedTime = parseISODate(lastEditedString),
            let properties = json["properties"] as? [String: Any]
        else { return nil }

        let title = (property(NotionPropertyName.title, in: properties)?["title"] as? [[String: Any]])?
            .first?["plain_text"] as? String ?? ""

        let number = property(NotionPropertyName.amount, in: properties)?["number"] as? Double
        if number == nil {
            Log.sync.warning("La página \(id, privacy: .public) de Notion no tiene cantidad; se usa 0")
        }

        let dateStart = (property(NotionPropertyName.date, in: properties)?["date"] as? [String: Any])?["start"] as? String
        let date = dateStart.flatMap { dateOnlyFormatter.date(from: $0) ?? parseISODate($0) }
        if date == nil {
            Log.sync.warning("La página \(id, privacy: .public) de Notion no tiene una fecha válida; se usa la fecha actual")
        }

        let paymentMethod = selectName(NotionPropertyName.paymentMethod, in: properties).flatMap(PaymentMethod.init(rawValue:))
        if paymentMethod == nil {
            Log.sync.warning("La página \(id, privacy: .public) de Notion no tiene un método de pago reconocido; se usa Tarjeta")
        }

        return ParsedNotionPage(
            id: id,
            lastEditedTime: lastEditedTime,
            archived: json["archived"] as? Bool ?? false,
            amount: number.map(decimalAmount) ?? 0,
            date: date ?? .now,
            title: title,
            paymentMethod: paymentMethod ?? .card,
            categoryName: selectName(NotionPropertyName.category, in: properties)
        )
    }

    static func parseISODate(_ string: String) -> Date? {
        isoDateTimeWithFractionFormatter.date(from: string) ?? isoDateTimeFormatter.date(from: string)
    }

    static func isoDateTime(_ date: Date) -> String {
        isoDateTimeFormatter.string(from: date)
    }

    static func isoDateOnly(_ date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }

    // MARK: - Ayudas de conversión

    private static func property(_ name: String, in properties: [String: Any]) -> [String: Any]? {
        properties[name] as? [String: Any]
    }

    private static func selectName(_ name: String, in properties: [String: Any]) -> String? {
        (property(name, in: properties)?["select"] as? [String: Any])?["name"] as? String
    }

    private static func selectSchema(optionNames: [String]) -> [String: Any] {
        ["select": ["options": optionNames.map { ["name": $0] }]]
    }

    // NSDecimalNumber.doubleValue no da el Double más cercano (19.99 → 19.990000000000002) y ese
    // ruido llegaba a Notion; pasar por el texto decimal sí lo da.
    private static func jsonNumber(_ amount: Decimal) -> Double {
        Double(NSDecimalNumber(decimal: amount).stringValue) ?? NSDecimalNumber(decimal: amount).doubleValue
    }

    // Nunca Decimal(double) directo: se convierte vía texto para evitar artefactos binarios
    // (p. ej. 19.99 → 19.989999999999998) que se colarían en el modelo local en cada pull.
    private static func decimalAmount(_ number: Double) -> Decimal {
        Decimal(string: String(format: "%.2f", number)) ?? Decimal(number)
    }

    // MARK: - Formateadores

    // ISO8601DateFormatter es seguro entre hilos, así que se reutiliza en vez de crearlo en cada llamada.
    private static let isoDateTimeWithFractionFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // Zona horaria local, no UTC: la fecha de un gasto es un día del calendario del usuario. En UTC,
    // un gasto apuntado poco después de medianoche en España llegaba a Notion con el día anterior.
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
}
