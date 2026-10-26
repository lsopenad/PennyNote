import Foundation
import WidgetKit

// Lo que la app publica en el App Group para los widgets. Sin dependencias de SwiftData/Modelos a
// propósito: se compila también en la extensión de widget, que no conoce Expense/ExpenseCategory.
struct WidgetSnapshot: Codable, Equatable {
    struct CategoryTotal: Codable, Equatable {
        let name: String
        let symbolName: String
        // rawValue de CategoryColor; nil para "Sin categoría".
        let colorName: String?
        let total: Decimal

        private enum CodingKeys: String, CodingKey {
            case name, symbolName, colorName, total
        }

        init(name: String, symbolName: String, colorName: String?, total: Decimal) {
            self.name = name
            self.symbolName = symbolName
            self.colorName = colorName
            self.total = total
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            symbolName = try container.decode(String.self, forKey: .symbolName)
            colorName = try container.decodeIfPresent(String.self, forKey: .colorName)
            total = try container.decode(DecimalText.self, forKey: .total).value
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(symbolName, forKey: .symbolName)
            try container.encodeIfPresent(colorName, forKey: .colorName)
            try container.encode(DecimalText(total), forKey: .total)
        }
    }

    let current: MonthSpending
    let previous: MonthSpending
    // Las categorías con más gasto del mes en curso, de mayor a menor.
    let topCategories: [CategoryTotal]
}

extension MonthSpending: Codable {
    private enum CodingKeys: String, CodingKey {
        case monthStart, dailyTotals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monthStart = try container.decode(Date.self, forKey: .monthStart)
        dailyTotals = try container.decode([DecimalText].self, forKey: .dailyTotals).map(\.value)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monthStart, forKey: .monthStart)
        try container.encode(dailyTotals.map(DecimalText.init), forKey: .dailyTotals)
    }
}

// Los importes cruzan el App Group (y la red, en la sincronización) como texto: JSONDecoder lee los
// Decimal pasando por Double y puede perder precisión (0.1 volvería como 0.1000000000000000512).
struct DecimalText: Codable {
    let value: Decimal

    init(_ value: Decimal) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Importe no válido: \(text)"))
        }
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(NSDecimalNumber(decimal: value).stringValue)
    }
}

// Lo que debe mostrar un widget en una fecha concreta. Si la app no se ha abierto desde que cambió
// el mes, el snapshot se ha quedado en un mes anterior y hay que deducir el mes en curso.
struct WidgetDisplay: Equatable {
    let current: MonthSpending
    // nil si no se sabe cuánto se gastó el mes anterior.
    let previous: MonthSpending?
    let topCategories: [WidgetSnapshot.CategoryTotal]
    // Día del mes en curso (1 = día 1).
    let day: Int

    var comparison: Double? {
        previous.flatMap { SpendingComparison.change(current: current, previous: $0, throughDay: day) }
    }

    init(snapshot: WidgetSnapshot?, at date: Date, calendar: Calendar = .current) {
        let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? date
        day = calendar.component(.day, from: date)

        guard let snapshot else {
            current = .empty(monthStart: monthStart, calendar: calendar)
            previous = nil
            topCategories = []
            return
        }

        let monthsSinceSnapshot = calendar.dateComponents([.month], from: snapshot.current.monthStart, to: monthStart).month ?? 0
        switch monthsSinceSnapshot {
        case ...0:
            // Mismo mes (o un reloj que ha ido hacia atrás): el snapshot sigue valiendo.
            current = snapshot.current
            previous = snapshot.previous
            topCategories = snapshot.topCategories
        case 1:
            // Ha empezado un mes nuevo: va a cero y lo que era el mes en curso pasa a ser el anterior.
            current = .empty(monthStart: monthStart, calendar: calendar)
            previous = snapshot.current
            topCategories = []
        default:
            current = .empty(monthStart: monthStart, calendar: calendar)
            previous = nil
            topCategories = []
        }
    }
}

enum WidgetSnapshotStore {
    static func write(_ snapshot: WidgetSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            AppGroupConstants.sharedDefaults.set(data, forKey: AppGroupConstants.Keys.widgetSnapshot)
        } catch {
            Log.widget.error("Fallo al guardar los datos del widget: \(error.localizedDescription)")
            return
        }
        // Siempre recarga: comparar para "ahorrar" recargas no compensa el riesgo de que una
        // comparación falle y el widget se quede pillado con un valor viejo.
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Al cerrar sesión: el widget vuelve a mostrar el mes vacío.
    static func clear() {
        AppGroupConstants.sharedDefaults.removeObject(forKey: AppGroupConstants.Keys.widgetSnapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> WidgetSnapshot? {
        guard let data = AppGroupConstants.sharedDefaults.data(forKey: AppGroupConstants.Keys.widgetSnapshot) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        } catch {
            Log.widget.error("Fallo al leer los datos del widget: \(error.localizedDescription)")
            return nil
        }
    }
}
