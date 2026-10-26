import Foundation

// Formateo de importes y meses compartido por la app y el widget (este fichero se compila en
// ambos targets). Los formateadores se crean una vez en vez de en cada evaluación de body.
enum DisplayFormat {
    private static let locale = Locale(identifier: "es_ES")

    private static let currencyFormatter = makeCurrencyFormatter()

    // Sin céntimos, para los huecos pequeños de la pantalla de bloqueo.
    private static let wholeCurrencyFormatter: NumberFormatter = {
        let formatter = makeCurrencyFormatter()
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "LLLL"
        return formatter
    }()

    static func currency(_ amount: Decimal, showsCents: Bool = true) -> String {
        let formatter = showsCents ? currencyFormatter : wholeCurrencyFormatter
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) €"
    }

    static func monthName(_ date: Date) -> String {
        monthFormatter.string(from: date).capitalized
    }

    private static func makeCurrencyFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        return formatter
    }
}
