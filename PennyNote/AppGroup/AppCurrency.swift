import Foundation

// Moneda en la que se muestran los importes. Una por cuenta: cambiarla solo cambia cómo se muestran,
// los importes no se convierten. Este fichero se compila también en el widget.
enum AppCurrency: String, CaseIterable, Identifiable {
    case eur = "EUR"
    case usd = "USD"
    case gbp = "GBP"
    case cny = "CNY"
    case jpy = "JPY"
    case mxn = "MXN"
    case chf = "CHF"
    case cad = "CAD"
    case ars = "ARS"
    case cop = "COP"

    var id: String { rawValue }

    // La de la región del móvil si está en la lista; si no, el euro.
    static func regionDefault(locale: Locale = .current) -> AppCurrency {
        locale.currency.flatMap { AppCurrency(rawValue: $0.identifier) } ?? .eur
    }

    // La elegida, guardada en el App Group para que la lea el widget; nil si aún no hay ninguna.
    static func stored(in defaults: UserDefaults = AppGroupConstants.sharedDefaults) -> AppCurrency? {
        defaults.string(forKey: AppGroupConstants.Keys.currency).flatMap(AppCurrency.init(rawValue:))
    }

    // Decimales con los que se muestra y se teclea, los mismos que usa el sistema al formatearla.
    var fractionDigits: Int {
        switch self {
        case .jpy, .cop: 0
        default: 2
        }
    }

    // "Dólar estadounidense", en el idioma del móvil.
    var localizedName: String {
        Locale.current.localizedString(forCurrencyCode: rawValue)?.capitalizedFirstLetter ?? rawValue
    }

    // "US$", "€"…: el símbolo que usa el formato del móvil.
    var symbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = rawValue
        return formatter.currencySymbol
    }

    // Icono de la pantalla de bloqueo.
    var symbolName: String {
        switch self {
        case .eur: "eurosign.circle"
        case .usd, .cad: "dollarsign.circle"
        case .gbp: "sterlingsign.circle"
        case .cny: "chineseyuanrenminbisign.circle"
        case .jpy: "yensign.circle"
        case .mxn, .ars, .cop: "pesosign.circle"
        case .chf: "francsign.circle"
        }
    }
}

private extension String {
    var capitalizedFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}
