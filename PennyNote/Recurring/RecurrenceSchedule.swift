import Foundation

// Fechas de las repeticiones de una serie. La repetición n es la fecha de inicio más n semanas, meses
// o años: Calendar lleva el día 31 al último día de los meses cortos (y el 29 de febrero al 28) sin
// que la serie se quede en ese día para siempre.
struct RecurrenceSchedule {
    let frequency: RecurrenceFrequency
    let startDate: Date
    var calendar: Calendar = .current

    func occurrence(_ index: Int) -> Date? {
        calendar.date(byAdding: frequency.component, value: index, to: startDate)
    }

    // Primera repetición posterior a `date`.
    func occurrence(after date: Date) -> Date? {
        firstOccurrence(near: date) { $0 > date }
    }

    // Primera repetición del mismo día que `date` o posterior, para reanudar una serie en pausa sin
    // recuperar las que tocaban mientras lo estaba.
    func firstOccurrence(onOrAfterDayOf date: Date) -> Date? {
        let startOfDay = calendar.startOfDay(for: date)
        return firstOccurrence(near: startOfDay) { $0 >= startOfDay }
    }

    // Los saltos no miden siempre lo mismo (meses de 28 a 31 días), así que se parte de una estimación
    // un poco por debajo de `date` y se avanza hasta la primera repetición que cumple.
    private func firstOccurrence(near date: Date, where isWanted: (Date) -> Bool) -> Date? {
        let elapsed = calendar.dateComponents([frequency.component], from: startDate, to: date).value(for: frequency.component) ?? 0
        var index = max(0, elapsed - 1)
        while let candidate = occurrence(index) {
            if isWanted(candidate) { return candidate }
            index += 1
        }
        return nil
    }
}
