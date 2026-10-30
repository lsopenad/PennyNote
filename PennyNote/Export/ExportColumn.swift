import Foundation

// Columnas de la lista de gastos exportada, iguales en CSV y en Excel.
enum ExportColumn: CaseIterable {
    case date
    case title
    case category
    case paymentMethod
    case amount

    func header(currency: AppCurrency) -> String {
        switch self {
        case .date: String(localized: "Fecha")
        case .title: String(localized: "Título")
        case .category: String(localized: "Categoría")
        case .paymentMethod: String(localized: "Método de pago")
        case .amount: String(localized: "Importe (\(currency.rawValue))", comment: "Cabecera de la columna de importes al exportar; el código es la moneda: «Importe (EUR)»")
        }
    }
}
