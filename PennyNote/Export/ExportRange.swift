import Foundation

// Periodo que se exporta desde Ajustes → Exportar.
enum ExportRange: String, CaseIterable, Identifiable {
    case thisMonth
    case lastMonth
    case thisYear
    case all
    case custom

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .thisMonth: "Este mes"
        case .lastMonth: "Mes pasado"
        case .thisYear: "Este año"
        case .all: "Todo"
        case .custom: "Personalizado"
        }
    }

    // Intervalo de los gastos que entran, con el final excluido; nil es sin límites. En personalizado
    // van del día `from` al día `to`, los dos incluidos y en cualquier orden. Si el calendario no
    // sabe calcular un mes o un año, el intervalo queda vacío: nunca se exporta todo por error.
    func interval(from: Date, to: Date, now: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        let empty = DateInterval(start: now, duration: 0)
        switch self {
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now) ?? empty
        case .lastMonth:
            return calendar.startOfPreviousMonth(for: now).flatMap { calendar.dateInterval(of: .month, for: $0) } ?? empty
        case .thisYear:
            return calendar.dateInterval(of: .year, for: now) ?? empty
        case .all:
            return nil
        case .custom:
            let start = calendar.startOfDay(for: min(from, to))
            let lastDay = calendar.startOfDay(for: max(from, to))
            let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
            return DateInterval(start: start, end: end)
        }
    }

    // Nombre del fichero, sin extensión: "PennyNote 2026-10", "PennyNote 2026",
    // "PennyNote 2026-09-01_2026-10-30" o "PennyNote". Con números para que se ordene bien en Archivos.
    func fileName(for interval: DateInterval?, calendar: Calendar = .current) -> String {
        guard let interval else { return "PennyNote" }
        let start = interval.start.gregorianDay(timeZone: calendar.timeZone)
        switch self {
        case .thisMonth, .lastMonth:
            return String(format: "PennyNote %04ld-%02ld", start.year, start.month)
        case .thisYear:
            return String(format: "PennyNote %04ld", start.year)
        case .all, .custom:
            let firstDay = CSVExporter.isoDay(interval.start, calendar: calendar)
            let lastDay = CSVExporter.isoDay(Self.lastDay(of: interval, calendar: calendar), calendar: calendar)
            return "PennyNote \(firstDay)_\(lastDay)"
        }
    }

    // Cómo se nombra el periodo en el resumen del Excel: "Octubre de 2026", "2026", "1 sept – 30 oct 2026".
    func periodTitle(for interval: DateInterval?, calendar: Calendar = .current) -> String {
        guard let interval else { return String(localized: "Todo") }
        switch self {
        case .thisMonth, .lastMonth:
            return DisplayFormat.monthAndYear(interval.start)
        case .thisYear:
            return interval.start.formatted(.dateTime.year())
        case .all, .custom:
            return DisplayFormat.dayRange(from: interval.start, to: Self.lastDay(of: interval, calendar: calendar))
        }
    }

    private static func lastDay(of interval: DateInterval, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -1, to: interval.end).map { max($0, interval.start) } ?? interval.start
    }
}

extension DateInterval {
    // contains(_:) incluye el final, que aquí es el primer instante del periodo siguiente.
    func includesExportDate(_ date: Date) -> Bool {
        start <= date && date < end
    }
}
