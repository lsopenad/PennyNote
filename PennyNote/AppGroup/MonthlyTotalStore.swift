import Foundation
import WidgetKit

// Sin dependencias de SwiftData/Modelos a propósito: este fichero tiene target membership
// compartida entre la app y la extensión de widget, que no conoce los tipos Expense/ExpenseCategory.
enum MonthlyTotalStore {
    // Guardado como String (no Double) para no perder precisión decimal al cruzar el App Group.
    static func write(total: Decimal, monthStart: Date) {
        let defaults = AppGroupConstants.sharedDefaults
        let newValue = NSDecimalNumber(decimal: total).stringValue

        defaults.set(newValue, forKey: AppGroupConstants.Keys.monthlyTotalAmount)
        defaults.set(monthStart, forKey: AppGroupConstants.Keys.monthlyTotalMonthStart)

        // Siempre recarga: comparar strings para "ahorrar" recargas no compensa el riesgo
        // de que una comparación falle y el widget se quede pillado con un valor viejo.
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> (total: Decimal, monthStart: Date)? {
        let defaults = AppGroupConstants.sharedDefaults
        guard
            let amountString = defaults.string(forKey: AppGroupConstants.Keys.monthlyTotalAmount),
            let amount = Decimal(string: amountString),
            let monthStart = defaults.object(forKey: AppGroupConstants.Keys.monthlyTotalMonthStart) as? Date
        else { return nil }
        return (amount, monthStart)
    }
}
