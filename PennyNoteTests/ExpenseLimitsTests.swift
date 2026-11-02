import Foundation
import Testing
@testable import PennyNote

// Postgres (char_length) cuenta code points y Swift cuenta caracteres: los recortes tienen que seguir
// al servidor sin partir nunca un carácter.
struct ExpenseLimitsTests {
    @Test func shortTitleIsKeptAsIs() {
        let title = "Caf\u{E9} con leche \u{1F44D}\u{1F3FD}"
        #expect(ExpenseLimits.clampedTitle(title) == title)
    }

    @Test func plainTitleIsCutAtTheLimit() {
        let clamped = ExpenseLimits.clampedTitle(String(repeating: "a", count: 600))
        #expect(clamped.unicodeScalars.count == ExpenseLimits.titleMaxLength)
    }

    // Cada carácter ocupa varios code points: el resultado no pasa del límite del servidor y no corta
    // ningún carácter por la mitad.
    @Test(arguments: [
        ("\u{1F44D}\u{1F3FD}", 2),                                                  // pulgar con tono de piel
        ("\u{1F1EA}\u{1F1F8}", 2),                                                  // bandera de España
        ("\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}", 7),        // familia con ZWJ
        ("e\u{301}", 2),                                                            // «é» con acento combinante
    ])
    func multiScalarCharactersStayWithinTheServerLimit(character: String, scalarsPerCharacter: Int) {
        let title = String(repeating: character, count: 300)

        let clamped = ExpenseLimits.clampedTitle(title)

        #expect(clamped.unicodeScalars.count <= ExpenseLimits.titleMaxLength)
        #expect(clamped.count == ExpenseLimits.titleMaxLength / scalarsPerCharacter)
        #expect(title.hasPrefix(clamped))
        #expect(clamped.allSatisfy { String($0) == character })
    }

    @Test func categoryNameFollowsItsOwnLimit() {
        let name = String(repeating: "\u{1F1EA}\u{1F1F8}", count: 80)  // 80 caracteres, 160 code points

        let clamped = ExpenseLimits.clampedCategoryName(name)

        #expect(clamped.unicodeScalars.count == ExpenseLimits.categoryNameMaxLength)
        #expect(clamped.count == 50)
    }
}
