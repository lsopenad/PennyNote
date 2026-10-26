import Foundation

// Gasto de un mes desglosado por día. Compartido con el widget, así que no depende de SwiftData.
struct MonthSpending: Equatable {
    let monthStart: Date
    // El índice 0 es el día 1; hay tantos elementos como días tiene el mes.
    let dailyTotals: [Decimal]

    var total: Decimal {
        dailyTotals.reduce(.zero, +)
    }

    // Suma de los días 1...day. Un día mayor que la longitud del mes cuenta el mes entero, que es
    // lo que se quiere al comparar el día 31 con un mes anterior de 30 días.
    func total(throughDay day: Int) -> Decimal {
        dailyTotals.prefix(max(day, 0)).reduce(.zero, +)
    }

    static func empty(monthStart: Date, calendar: Calendar = .current) -> MonthSpending {
        let dayCount = calendar.numberOfDays(inMonthOf: monthStart) ?? 31
        return MonthSpending(monthStart: monthStart, dailyTotals: Array(repeating: .zero, count: dayCount))
    }
}

enum SpendingComparison {
    // Variación (0.12 = +12 %) del gasto acumulado hasta `day` respecto al mismo tramo del mes
    // anterior. nil si el mes anterior no tiene gasto en ese tramo: no hay base para el porcentaje.
    static func change(current: MonthSpending, previous: MonthSpending, throughDay day: Int) -> Double? {
        let base = previous.total(throughDay: day)
        guard base > 0 else { return nil }
        return ((current.total(throughDay: day) - base) / base).doubleValue
    }
}

extension Sequence {
    // Suma de importes en Decimal, sin pasar por Double.
    func sum(of amount: (Element) -> Decimal) -> Decimal {
        reduce(.zero) { $0 + amount($1) }
    }
}

extension Decimal {
    // Solo para dibujar (gráficas, porcentajes): los importes se siguen sumando como Decimal.
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
