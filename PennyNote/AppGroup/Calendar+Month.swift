import Foundation

// Aritmética de meses compartida por la app y el widget (este fichero se compila en ambos targets).
extension Calendar {
    // Primer instante del mes de `date`; la propia fecha si el calendario no sabe calcularlo.
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? date
    }

    func startOfPreviousMonth(for date: Date) -> Date? {
        self.date(byAdding: .month, value: -1, to: startOfMonth(for: date))
    }

    func numberOfDays(inMonthOf date: Date) -> Int? {
        range(of: .day, in: .month, for: date)?.count
    }
}
