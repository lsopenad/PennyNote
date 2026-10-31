import Foundation

// Formateo de importes y meses compartido por la app y el widget (este fichero se compila en
// ambos targets). Los formateadores se crean una vez en vez de en cada evaluación de body.
enum DisplayFormat {
    // El idioma y la región del móvil (el idioma, entre los que tiene la app). Si cambian, iOS
    // reinicia la app, así que basta con leerlos al crear los formateadores.
    private static let locale = Locale.current

    private static let monthFormatter = makeTemplateFormatter("LLLL")
    private static let shortMonthFormatter = makeTemplateFormatter("LLL")
    private static let monthAndYearFormatter = makeTemplateFormatter("yMMMM")
    private static let shortDayFormatter = makeTemplateFormatter("dMMM")
    private static let fullDayFormatter = makeTemplateFormatter("EEEEdMMMy")

    private static let dayRangeFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.dateTemplate = "dMMMy"
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = locale
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    // Igual que percentFormatter pero siempre con signo, para variaciones. Redondea como rounded() en
    // comparison: con el redondeo al par por defecto, un 0,5 % saldría como "+0 %".
    private static let signedPercentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = locale
        formatter.maximumFractionDigits = 0
        formatter.roundingMode = .halfUp
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
        capitalizingFirstLetter(monthFormatter.string(from: date))
    }

    // "Octubre de 2026", "October 2026", "2026年10月".
    static func monthAndYear(_ date: Date) -> String {
        capitalizingFirstLetter(monthAndYearFormatter.string(from: date))
    }

    // "26 oct – 1 nov 2026", con los dos días incluidos.
    static func dayRange(from firstDay: Date, to lastDay: Date) -> String {
        dayRangeFormatter.string(from: firstDay, to: lastDay)
    }

    // "Jueves, 29 de oct de 2026".
    static func fullDay(_ date: Date) -> String {
        capitalizingFirstLetter(fullDayFormatter.string(from: date))
    }

    // "oct", para las barras de la evolución por meses.
    static func shortMonth(_ date: Date) -> String {
        shortMonthFormatter.string(from: date)
    }

    // "26 oct", para las barras de la evolución por semanas.
    static func shortDay(_ date: Date) -> String {
        shortDayFormatter.string(from: date)
    }

    // 0.38 -> "38 %".
    static func percent(_ fraction: Double) -> String {
        percentFormatter.string(from: fraction as NSNumber) ?? ""
    }

    // Variación respecto al mismo día del mes anterior: "−12 % vs septiembre a estas alturas", o
    // "−12 % vs sept." en corto para los widgets.
    static func comparison(_ change: Double, previousMonth: Date, short: Bool = false) -> String {
        let month = short ? shortMonthFormatter.string(from: previousMonth) : monthFormatter.string(from: previousMonth)
        // Lo que redondea a 0 % se dice con palabras: "+0 %" o "−0 %" despistan.
        guard (change * 100).rounded() != 0 else {
            return short
                ? String(localized: "Igual que \(month)", comment: "Widget: gasto igual que el mes anterior")
                : String(localized: "Igual que \(month) a estas alturas", comment: "Gasto igual que el mes anterior hasta el mismo día")
        }
        let percentText = signedPercentFormatter.string(from: change as NSNumber) ?? ""
        return short
            ? String(localized: "\(percentText) vs \(month)", comment: "Widget: «−12 % vs sept»")
            : String(localized: "\(percentText) vs \(month) a estas alturas", comment: "«−12 % vs septiembre a estas alturas»")
    }

    private static func makeTemplateFormatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    // Solo la primera letra: capitalized pondría en mayúscula también el "de" de "octubre de 2026".
    private static func capitalizingFirstLetter(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}
