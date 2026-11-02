import Foundation
import Testing
@testable import PennyNote

struct AmountInputTests {
    @Test(arguments: [
        ("12,5", "12.5"),
        ("12.5", "12.5"),
        (",5", "0.5"),
        ("12,", "12"),
        ("1000", "1000"),
        ("0,01", "0.01"),
        (" 12,50 ", "12.5"),
    ])
    func readsTheDecimalSeparatorOfAnyKeyboard(text: String, expected: String) {
        #expect(input(text).value == Decimal(string: expected))
    }

    // Texto pegado o de un teclado físico: mejor rechazarlo que guardar otro importe.
    @Test(arguments: ["1.234,56", "1,234.56", "1 234,56", "12abc", "1e3", "12,5,3", "12 €"])
    func rejectsTextThatIsNotASingleNumber(text: String) {
        #expect(input(text).value == nil)
    }

    // Un importe guardado se muestra con el separador del teclado y sin agrupar miles, y se lee igual.
    @Test(arguments: [("es_ES", "1234,56"), ("en_US", "1234.56"), ("zh_CN", "1234.56")])
    func showsAnAmountWithTheDecimalSeparatorOfTheLocale(identifier: String, expected: String) {
        let amount = Decimal(string: "1234.56")
        let input = AmountInput(amount, locale: Locale(identifier: identifier))

        #expect(input.text == expected)
        #expect(input.value == amount)
    }

    private func input(_ text: String) -> AmountInput {
        var input = AmountInput()
        input.text = text
        return input
    }
}
