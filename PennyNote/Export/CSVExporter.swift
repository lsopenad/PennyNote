import Foundation

// Lista de gastos en CSV, pensada para abrirla con doble clic en una hoja de cálculo del mismo país:
// donde la coma es el separador decimal se separa con «;», como espera Excel en esos idiomas.
enum CSVExporter {
    static func data(for rows: [ExportRow], currency: AppCurrency, locale: Locale = .current, calendar: Calendar = .current) -> Data {
        let separator = locale.decimalSeparator == "," ? ";" : ","
        let amountStyle = Decimal.FormatStyle(locale: locale)
            .precision(.fractionLength(currency.fractionDigits))
            .grouping(.never)

        var lines = [ExportColumn.allCases.map { escaped($0.header(currency: currency), separator: separator) }]
        for row in rows {
            lines.append([
                isoDay(row.date, calendar: calendar),
                escaped(row.title, separator: separator),
                escaped(row.categoryName, separator: separator),
                escaped(row.paymentMethodName, separator: separator),
                row.amount.formatted(amountStyle),
            ])
        }
        let text = lines.map { $0.joined(separator: separator) }.joined(separator: "\r\n") + "\r\n"
        // Con BOM, Excel lo abre como UTF-8 y no rompe las tildes ni el chino.
        return Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
    }

    // "2026-10-30": el formato de fecha que todas las hojas de cálculo reconocen, sea cual sea el idioma.
    static func isoDay(_ date: Date, calendar: Calendar) -> String {
        let day = date.gregorianDay(timeZone: calendar.timeZone)
        return String(format: "%04ld-%02ld-%02ld", day.year, day.month, day.day)
    }

    // Entre comillas si contiene el separador, comillas o saltos de línea (RFC 4180). Lo que empieza
    // como una fórmula (=, +, -, @) lleva delante un apóstrofo para que la hoja de cálculo no la ejecute.
    static func escaped(_ field: String, separator: String) -> String {
        var value = field
        if let first = value.unicodeScalars.first, "=+-@\t\r".unicodeScalars.contains(first) {
            value = "'" + value
        }
        guard value.contains(separator) || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
