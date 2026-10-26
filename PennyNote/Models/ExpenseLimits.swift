import Foundation

// Límites que impone el esquema de Supabase (CHECK de supabase/migrations). Si un dato local se los
// salta, el servidor rechaza el lote entero de la subida y la sincronización se queda atascada.
enum ExpenseLimits {
    static let maxAmountExclusive: Decimal = 1_000_000_000
    static let titleMaxLength = 500
    static let categoryNameMaxLength = 100

    static func isValidAmount(_ amount: Decimal) -> Bool {
        amount > 0 && amount < maxAmountExclusive
    }

    static func clampedTitle(_ title: String) -> String {
        String(title.prefix(titleMaxLength))
    }

    static func clampedCategoryName(_ name: String) -> String {
        String(name.prefix(categoryNameMaxLength))
    }
}
