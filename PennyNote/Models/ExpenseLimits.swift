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

    // Sin más decimales de los que usa la moneda (ninguno en yenes): no se podrían mostrar.
    static func hasValidFractionDigits(_ amount: Decimal, for currency: AppCurrency) -> Bool {
        var value = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, currency.fractionDigits, .plain)
        return rounded == amount
    }

    static func clampedTitle(_ title: String) -> String {
        prefix(title, maxCodePoints: titleMaxLength)
    }

    static func clampedCategoryName(_ name: String) -> String {
        prefix(name, maxCodePoints: categoryNameMaxLength)
    }

    // Postgres (char_length) cuenta code points y no caracteres de Swift: un emoji con tono de piel o
    // una bandera es un carácter y varios code points. Se corta por caracteres enteros, sin partir ninguno.
    private static func prefix(_ text: String, maxCodePoints: Int) -> String {
        guard text.unicodeScalars.count > maxCodePoints else { return text }
        var result = ""
        var codePoints = 0
        for character in text {
            let size = character.unicodeScalars.count
            guard codePoints + size <= maxCodePoints else { break }
            result.append(character)
            codePoints += size
        }
        return result
    }
}
