import Foundation
import Testing
@testable import PennyNote

struct ExportTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }

    private func row(_ title: String, amount: String, date: Date, category: String = "Comida") throws -> ExportRow {
        ExportRow(date: date, title: title, categoryName: category, paymentMethodName: "Tarjeta", amount: try #require(Decimal(string: amount)))
    }

    private func csvLines(_ data: Data) throws -> [String] {
        #expect(data.starts(with: [0xEF, 0xBB, 0xBF]))
        let text = try #require(String(data: data.dropFirst(3), encoding: .utf8))
        #expect(text.hasSuffix("\r\n"))
        return text.components(separatedBy: "\r\n").dropLast()
    }

    // MARK: - CSV

    @Test func csvUsesSemicolonAndDecimalCommaWhereTheLocaleDoes() throws {
        let rows = [try row("Pan", amount: "1234.5", date: try date(2026, 10, 30, hour: 23))]

        let lines = try csvLines(CSVExporter.data(for: rows, currency: .eur, locale: Locale(identifier: "es_ES"), calendar: calendar))

        #expect(lines.count == 2)
        #expect(lines[0].components(separatedBy: ";").count == 5)
        #expect(lines[1] == "2026-10-30;Pan;Comida;Tarjeta;1234,50")
    }

    @Test func csvUsesCommaAndDecimalPointElsewhere() throws {
        let rows = [try row("Pan, leche", amount: "3", date: try date(2026, 1, 2))]

        let lines = try csvLines(CSVExporter.data(for: rows, currency: .usd, locale: Locale(identifier: "en_US"), calendar: calendar))

        #expect(lines[1] == "2026-01-02,\"Pan, leche\",Comida,Tarjeta,3.00")
    }

    @Test func csvAmountsFollowTheCurrencyDecimals() throws {
        let rows = [try row("Ramen", amount: "1200", date: try date(2026, 5, 5))]

        let lines = try csvLines(CSVExporter.data(for: rows, currency: .jpy, locale: Locale(identifier: "ja_JP"), calendar: calendar))

        #expect(lines[1].hasSuffix(",1200"))
    }

    @Test(arguments: [
        ("=SUM(A1)", "'=SUM(A1)"),
        ("+34 600", "'+34 600"),
        ("-5", "'-5"),
        ("@cmd", "'@cmd"),
        ("Dice \"hola\"", "\"Dice \"\"hola\"\"\""),
        ("Dos\nlíneas", "\"Dos\nlíneas\""),
        ("Normal", "Normal"),
    ])
    func csvEscapesQuotesLineBreaksAndFormulas(field: String, expected: String) {
        #expect(CSVExporter.escaped(field, separator: ";") == expected)
    }

    @Test func csvDatesAreGregorianWhateverTheCalendar() throws {
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = calendar.timeZone

        #expect(CSVExporter.isoDay(try date(2026, 10, 30), calendar: japanese) == "2026-10-30")
    }

    // MARK: - Excel

    @Test func excelWritesAWorkbookWithBothSheetsAndCharts() throws {
        let rows = [
            try row("Pan", amount: "2.5", date: try date(2026, 8, 3)),
            try row("Bus", amount: "10", date: try date(2026, 10, 1), category: "Transporte"),
            try row("Control\u{1}", amount: "4", date: try date(1850, 1, 1)),
        ]
        let directory = FileManager.default.temporaryDirectory.appending(path: "ExportTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Gastos ñ.xlsx")

        try ExcelExporter.write(rows, to: url, currency: .eur, periodTitle: "Todo", locale: Locale(identifier: "es_ES"), calendar: calendar)

        // Un .xlsx es un zip: los nombres de sus partes aparecen sin comprimir en el índice.
        let data = try Data(contentsOf: url)
        #expect(data.starts(with: Array("PK".utf8)))
        for part in ["xl/worksheets/sheet1.xml", "xl/worksheets/sheet2.xml", "xl/charts/chart1.xml", "xl/charts/chart2.xml"] {
            #expect(data.range(of: Data(part.utf8)) != nil, "Falta \(part)")
        }
    }

    @Test func excelCurrencyFormatPlacesTheSymbolLikeTheLocale() {
        #expect(ExcelExporter.currencyNumberFormat(.eur, locale: Locale(identifier: "es_ES")) == "#,##0.00 \"€\"")
        #expect(ExcelExporter.currencyNumberFormat(.eur, locale: Locale(identifier: "en_IE")) == "\"€\"#,##0.00")
        #expect(ExcelExporter.currencyNumberFormat(.jpy, locale: Locale(identifier: "en_US")).hasSuffix("#,##0"))
    }

    // MARK: - Periodo

    @Test func lastMonthInJanuaryIsDecemberOfThePreviousYear() throws {
        let interval = try #require(ExportRange.lastMonth.interval(from: .now, to: .now, now: try date(2026, 1, 15), calendar: calendar))

        #expect(interval.start == (try date(2025, 12, 1, hour: 0)))
        #expect(interval.end == (try date(2026, 1, 1, hour: 0)))
        #expect(ExportRange.lastMonth.fileName(for: interval, calendar: calendar) == "PennyNote 2025-12")
    }

    @Test func customRangeIncludesBothDaysInAnyOrder() throws {
        let interval = try #require(ExportRange.custom.interval(from: try date(2026, 10, 30), to: try date(2026, 9, 1), calendar: calendar))

        #expect(interval.includesExportDate(try date(2026, 9, 1, hour: 0)))
        #expect(interval.includesExportDate(try date(2026, 10, 30, hour: 23)))
        #expect(!interval.includesExportDate(try date(2026, 10, 31, hour: 0)))
        #expect(ExportRange.custom.fileName(for: interval, calendar: calendar) == "PennyNote 2026-09-01_2026-10-30")
    }

    @Test func allHasNoLimits() {
        #expect(ExportRange.all.interval(from: .now, to: .now) == nil)
        #expect(ExportRange.all.fileName(for: nil) == "PennyNote")
    }
}
