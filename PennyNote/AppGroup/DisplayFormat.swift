import Foundation

// Formateo de importes y meses compartido por la app y el widget (este fichero se compila en
// ambos targets). Los formateadores se crean una vez en vez de en cada evaluación de body.
enum DisplayFormat {
    // Los importes siguen el formato del móvil; los textos, de momento, siempre en español.
    private static let locale = Locale(identifier: "es_ES")

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

    // Con los decimales de la moneda (ninguno en yenes), o sin ellos para los huecos pequeños de la
    // pantalla de bloqueo. Decimal.FormatStyle reutiliza por dentro el formateador de cada moneda.
    static func currency(_ amount: Decimal, in currency: AppCurrency, showsCents: Bool = true) -> String {
        let style = Decimal.FormatStyle.Currency(code: currency.rawValue, locale: .current)
        return showsCents ? amount.formatted(style) : amount.formatted(style.precision(.fractionLength(0)))
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
}
