import Foundation
import Testing
@testable import PennyNote

struct DisplayFormatTests {
    // 201 € frente a 200 € es +0,5 %: con el redondeo al par del formateador salía «+0 %».
    @Test(arguments: [
        (0.005, "+1"),
        (-0.005, "−1"),
        (0.025, "+3"),
    ])
    func halfPercentChangesRoundAwayFromZero(change: Double, expectedPrefix: String) throws {
        let previousMonth = try #require(DateComponents(calendar: .current, year: 2026, month: 9, day: 1).date)

        #expect(DisplayFormat.comparison(change, previousMonth: previousMonth).hasPrefix(expectedPrefix))
        #expect(DisplayFormat.comparison(change, previousMonth: previousMonth, short: true).hasPrefix(expectedPrefix))
    }

    @Test(arguments: [0.004, -0.0049])
    func changesThatRoundToZeroAreShownAsEqual(change: Double) throws {
        let previousMonth = try #require(DateComponents(calendar: .current, year: 2026, month: 9, day: 1).date)

        #expect(DisplayFormat.comparison(change, previousMonth: previousMonth) == DisplayFormat.comparison(0, previousMonth: previousMonth))
        #expect(DisplayFormat.comparison(change, previousMonth: previousMonth, short: true) == DisplayFormat.comparison(0, previousMonth: previousMonth, short: true))
    }
}
