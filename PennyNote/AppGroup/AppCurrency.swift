import Foundation
import UIKit

// Moneda en la que se muestran los importes. Una por cuenta: cambiarla solo cambia cómo se muestran,
// los importes no se convierten. Este fichero se compila también en el widget.
struct AppCurrency: RawRepresentable, Hashable, Identifiable, Sendable {
    // Código ISO 4217: "EUR".
    let rawValue: String
    // Decimales con los que se muestra y se teclea (0 en yenes, 3 en dinares kuwaitíes), los mismos
    // que usa el sistema al formatearla.
    let fractionDigits: Int
    // "US$", "€"…: el símbolo que usa el formato del móvil.
    let symbol: String

    // Cualquier código ISO 4217 que conozca el sistema, también los de monedas retiradas: una moneda
    // guardada o que llega del servidor se respeta aunque iOS la haya quitado de la lista.
    init?(rawValue: String) {
        guard Self.isoCodes.contains(rawValue) else { return nil }
        self.init(known: rawValue)
    }

    // Decimales y símbolo se leen aquí una vez: el campo de importe los consulta en cada pulsación.
    private init(known code: String) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        rawValue = code
        fractionDigits = formatter.maximumFractionDigits
        symbol = formatter.currencySymbol
    }

    // Iguales si tienen el mismo código: decimales y símbolo salen de él.
    static func == (lhs: AppCurrency, rhs: AppCurrency) -> Bool {
        lhs.rawValue == rhs.rawValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }

    static let eur = AppCurrency(known: "EUR")

    // Las que se ofrecen al elegir: las que están en uso según el sistema, por nombre en el idioma
    // del móvil. Si el idioma cambia, iOS reinicia la app, así que basta con ordenarlas una vez.
    static let all: [AppCurrency] = Locale.commonISOCurrencyCodes
        .filter { !replacedCodes.contains($0) }
        .compactMap(AppCurrency.init(rawValue:))
        .sorted { $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending }

    // iOS aún da por comunes algunas ya sustituidas por otra moneda (la kuna y la leva por el euro, el
    // florín antillano por el caribeño…). No se ofrecen, pero quien ya las tenga elegidas las conserva.
    static let replacedCodes: Set<String> = ["ANG", "BGN", "CUC", "HRK", "SLL", "VEF"]

    private static let isoCodes = Set(Locale.Currency.isoCurrencies.map(\.identifier))

    var id: String { rawValue }

    // La de la región del móvil, o el euro si la región no tiene o si es una ya sustituida (un iOS 18
    // aún da la leva para Bulgaria, que ha pasado al euro).
    static func regionDefault(locale: Locale = .current) -> AppCurrency {
        guard let code = locale.currency?.identifier, !replacedCodes.contains(code),
              let currency = AppCurrency(rawValue: code) else { return .eur }
        return currency
    }

    // La elegida, guardada en el App Group para que la lea el widget; nil si aún no hay ninguna.
    static func stored(in defaults: UserDefaults = AppGroupConstants.sharedDefaults) -> AppCurrency? {
        defaults.string(forKey: AppGroupConstants.Keys.currency).flatMap(AppCurrency.init(rawValue:))
    }

    // "Dólar estadounidense", en el idioma del móvil.
    var localizedName: String {
        Locale.current.localizedString(forCurrencyCode: rawValue)?.capitalizedFirstLetter ?? rawValue
    }

    // "Dólar estadounidense (US$)": en la lista de monedas y en Ajustes.
    var displayName: String {
        "\(localizedName) (\(symbol))"
    }

    // Icono de la pantalla de bloqueo: el signo propio de la moneda si SF Symbols lo tiene en esta
    // versión de iOS (algunos son más recientes que la 18), o un billete.
    var symbolName: String {
        guard let base = Self.symbolBaseNames[rawValue] else { return Self.fallbackSymbolName }
        let name = "\(base).circle"
        return UIImage(systemName: name) != nil ? name : Self.fallbackSymbolName
    }

    static let fallbackSymbolName = "banknote"

    // Signo de SF Symbols de cada moneda que tiene uno (sin el ".circle").
    static let symbolBaseNames: [String: String] = {
        let groups: [String: [String]] = [
            "eurosign": ["EUR"],
            "dollarsign": [
                "USD", "CAD", "AUD", "NZD", "HKD", "TWD", "BSD", "BBD", "BZD", "BMD", "BND", "FJD", "GYD",
                "JMD", "KYD", "LRD", "NAD", "SBD", "SRD", "TTD", "XCD",
            ],
            "singaporedollarsign": ["SGD"],
            "pesosign": ["MXN", "ARS", "CLP", "COP", "CUP", "DOP", "PHP", "UYU"],
            "sterlingsign": ["GBP", "FKP", "GIP", "SHP"],
            "yensign": ["JPY"],
            "chineseyuanrenminbisign": ["CNY"],
            "francsign": ["CHF", "XAF", "XOF", "XPF", "CDF", "BIF", "DJF", "GNF", "KMF", "RWF"],
            "indianrupeesign": ["INR"],
            "rupeesign": ["PKR", "LKR", "NPR", "MUR", "SCR"],
            "wonsign": ["KRW", "KPW"],
            "rublesign": ["RUB"],
            "turkishlirasign": ["TRY"],
            "shekelsign": ["ILS"],
            "bahtsign": ["THB"],
            "dongsign": ["VND"],
            "nairasign": ["NGN"],
            "hryvniasign": ["UAH"],
            "tengesign": ["KZT"],
            "larisign": ["GEL"],
            "manatsign": ["AZN", "TMT"],
            "tugriksign": ["MNT"],
            "guaranisign": ["PYG"],
            "cedisign": ["GHS"],
            "coloncurrencysign": ["CRC"],
            "kipsign": ["LAK"],
            "florinsign": ["AWG"],
            "brazilianrealsign": ["BRL"],
            "polishzlotysign": ["PLN"],
            "malaysianringgitsign": ["MYR"],
            "norwegiankronesign": ["NOK"],
            "swedishkronasign": ["SEK"],
            "danishkronesign": ["DKK"],
        ]
        return Dictionary(uniqueKeysWithValues: groups.flatMap { base, codes in codes.map { ($0, base) } })
    }()
}

private extension String {
    var capitalizedFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}
