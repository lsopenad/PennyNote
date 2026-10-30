import Foundation

extension Date {
    // Año, mes y día del calendario gregoriano en `timeZone`: los ficheros
    // exportados usan siempre ese calendario, aunque el móvil use otro (japonés, budista…).
    func gregorianDay(timeZone: TimeZone) -> (year: Int, month: Int, day: Int) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: self)
        return (parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
