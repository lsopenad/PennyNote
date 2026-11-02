@testable import PennyNote

// Monedas con nombre para los tests: la app solo necesita el euro como constante.
extension AppCurrency {
    static let usd = AppCurrency(rawValue: "USD")!
    static let gbp = AppCurrency(rawValue: "GBP")!
    static let jpy = AppCurrency(rawValue: "JPY")!
    static let mxn = AppCurrency(rawValue: "MXN")!
    static let cad = AppCurrency(rawValue: "CAD")!
    static let chf = AppCurrency(rawValue: "CHF")!
    static let cop = AppCurrency(rawValue: "COP")!
    static let brl = AppCurrency(rawValue: "BRL")!
    static let kwd = AppCurrency(rawValue: "KWD")!
}
