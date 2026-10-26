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

    private static let monthFormatter = makeDateFormatter("LLLL")
    private static let shortMonthFormatter = makeDateFormatter("LLL")
    private static let monthAndYearFormatter = makeDateFormatter("LLLL yyyy")

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = locale
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    // Igual que percentFormatter pero siempre con signo, para variaciones.
    private static let signedPercentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = locale
        formatter.maximumFractionDigits = 0
        formatter.positivePrefix = "+"
        formatter.negativePrefix = "−"
        return formatter
    }()

    static func currency(_ amount: Decimal, showsCents: Bool = true) -> String {
        let formatter = showsCents ? currencyFormatter : wholeCurrencyFormatter
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) €"
    }

    static func monthName(_ date: Date) -> String {
        monthFormatter.string(from: date).capitalized
    }

    // "Octubre 2026".
    static func monthAndYear(_ date: Date) -> String {
        monthAndYearFormatter.string(from: date).capitalized
    }

    // 0.38 -> "38 %".
    static func percent(_ fraction: Double) -> String {
        percentFormatter.string(from: fraction as NSNumber) ?? ""
    }

    // Variación respecto al mismo día del mes anterior: "−12 % vs septiembre a estas alturas", o
    // "−12 % vs sept." en corto para los widgets.
    static func comparison(_ change: Double, previousMonth: Date, short: Bool = false) -> String {
        let month = short ? shortMonthFormatter.string(from: previousMonth) + "." : monthFormatter.string(from: previousMonth)
        // Lo que redondea a 0 % se dice con palabras: "+0 %" o "−0 %" despistan.
        guard (change * 100).rounded() != 0 else {
            return short ? "Igual que \(month)" : "Igual que \(month) a estas alturas"
        }
        let percentText = signedPercentFormatter.string(from: change as NSNumber) ?? ""
        return short ? "\(percentText) vs \(month)" : "\(percentText) vs \(month) a estas alturas"
    }

    private static func makeDateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter
    }

    private static func makeCurrencyFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        return formatter
    }
}
