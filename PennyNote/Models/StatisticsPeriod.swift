import Foundation

// Periodo que se ve en Estadísticas: un mes, una semana natural (según el primer día de la semana
// del calendario del móvil) o un día.
struct StatisticsPeriod: Hashable {
    enum Kind: String, CaseIterable, Identifiable {
        case month
        case week
        case day

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .month: "Mes"
            case .week: "Semana"
            case .day: "Día"
            }
        }

        fileprivate var component: Calendar.Component {
            switch self {
            case .month: .month
            case .week: .weekOfYear
            case .day: .day
            }
        }
    }

    let kind: Kind
    // Primer instante del periodo.
    let start: Date

    init(kind: Kind, containing date: Date, calendar: Calendar = .current) {
        self.kind = kind
        start = calendar.dateInterval(of: kind.component, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    func interval(calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: kind.component, for: start) ?? DateInterval(start: start, duration: 0)
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let interval = interval(calendar: calendar)
        return date >= interval.start && date < interval.end
    }

    // El periodo `offset` posiciones antes (negativo) o después.
    func moved(by offset: Int, calendar: Calendar = .current) -> StatisticsPeriod {
        let date = calendar.date(byAdding: kind.component, value: offset, to: start) ?? start
        return StatisticsPeriod(kind: kind, containing: date, calendar: calendar)
    }

    // Al cambiar de modo: el periodo que contiene hoy si este lo contiene; si no, el que contiene su
    // primer día (agosto → semana del 1 de agosto).
    func converted(to kind: Kind, now: Date = .now, calendar: Calendar = .current) -> StatisticsPeriod {
        let anchor = contains(now, calendar: calendar) ? now : start
        return StatisticsPeriod(kind: kind, containing: anchor, calendar: calendar)
    }

    // Primer instante de cada día del periodo, en orden.
    func days(calendar: Calendar = .current) -> [Date] {
        let interval = interval(calendar: calendar)
        var days: [Date] = []
        var day = interval.start
        while day < interval.end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    // "Octubre 2026", "26 oct – 1 nov 2026" o "Jueves, 29 de oct de 2026".
    func title(calendar: Calendar = .current) -> String {
        switch kind {
        case .month:
            return DisplayFormat.monthAndYear(start)
        case .week:
            let lastDay = days(calendar: calendar).last ?? start
            return DisplayFormat.dayRange(from: start, to: lastDay)
        case .day:
            return DisplayFormat.fullDay(start)
        }
    }
}
