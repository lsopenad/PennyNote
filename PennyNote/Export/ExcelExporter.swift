import Foundation
import libxlsxwriter

// Libro de Excel con dos hojas: la lista de gastos y un resumen por categoría, método de pago y mes,
// con un gráfico circular por categoría y otro de barras por mes. Las cifras se escriben ya
// calculadas y no como fórmulas: libxlsxwriter no calcula, y la vista previa de iOS no recalcula.
enum ExcelExporter {
    struct WriteError: LocalizedError {
        let code: lxw_error

        var errorDescription: String? {
            "No se pudo generar el Excel: \(String(cString: lxw_strerror(code)))"
        }
    }

    static func write(
        _ rows: [ExportRow],
        to url: URL,
        currency: AppCurrency,
        periodTitle: String,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) throws {
        let path = url.path(percentEncoded: false)
        let temporaryDirectory = FileManager.default.temporaryDirectory.path(percentEncoded: false)
        // libxlsxwriter crea ficheros temporales al cerrar el libro; fuera del directorio temporal de
        // la app, el sandbox de iOS no le deja.
        let result = temporaryDirectory.withCString { tmpdir in
            var options = lxw_workbook_options()
            options.tmpdir = tmpdir
            guard let workbook = workbook_new_opt(path, &options) else {
                return LXW_ERROR_CREATING_XLSX_FILE
            }
            let formats = Formats(workbook: workbook, currencyFormat: currencyNumberFormat(currency, locale: locale))
            addExpensesSheet(rows, to: workbook, formats: formats, currency: currency, calendar: calendar)
            addSummarySheet(rows, to: workbook, formats: formats, periodTitle: periodTitle, locale: locale, calendar: calendar)
            return workbook_close(workbook)
        }
        guard result == LXW_NO_ERROR else { throw WriteError(code: result) }
    }

    // MARK: - Hojas

    private static func addExpensesSheet(
        _ rows: [ExportRow],
        to workbook: UnsafeMutablePointer<lxw_workbook>,
        formats: Formats,
        currency: AppCurrency,
        calendar: Calendar
    ) {
        let sheet = workbook_add_worksheet(workbook, String(localized: "Gastos"))
        let columns = ExportColumn.allCases
        for (index, column) in columns.enumerated() {
            worksheet_write_string(sheet, 0, col(index), column.header(currency: currency), formats.header)
        }
        for (index, row) in rows.enumerated() {
            let line = lxw_row_t(index + 1)
            writeDate(row.date, sheet: sheet, row: line, col: 0, format: formats.date, calendar: calendar)
            worksheet_write_string(sheet, line, 1, cleaned(row.title), nil)
            worksheet_write_string(sheet, line, 2, cleaned(row.categoryName), nil)
            worksheet_write_string(sheet, line, 3, cleaned(row.paymentMethodName), nil)
            worksheet_write_number(sheet, line, 4, row.amount.doubleValue, formats.money)
        }
        worksheet_set_column(sheet, 0, 0, 12, nil)
        worksheet_set_column(sheet, 1, 1, 32, nil)
        worksheet_set_column(sheet, 2, 3, 18, nil)
        worksheet_set_column(sheet, 4, 4, 14, nil)
        worksheet_freeze_panes(sheet, 1, 0)
        worksheet_autofilter(sheet, 0, 0, lxw_row_t(rows.count), col(columns.count - 1))
    }

    private static func addSummarySheet(
        _ rows: [ExportRow],
        to workbook: UnsafeMutablePointer<lxw_workbook>,
        formats: Formats,
        periodTitle: String,
        locale: Locale,
        calendar: Calendar
    ) {
        let sheetName = String(localized: "Resumen")
        let sheet = workbook_add_worksheet(workbook, sheetName)
        let total = rows.reduce(Decimal.zero) { $0 + $1.amount }

        worksheet_write_string(sheet, 0, 0, String(localized: "Periodo"), formats.header)
        worksheet_write_string(sheet, 0, 1, cleaned(periodTitle), nil)
        worksheet_write_string(sheet, 1, 0, String(localized: "Total"), formats.header)
        worksheet_write_number(sheet, 1, 1, total.doubleValue, formats.money)
        worksheet_write_string(sheet, 2, 0, String(localized: "Número de gastos"), formats.header)
        worksheet_write_number(sheet, 2, 1, Double(rows.count), nil)

        var line: lxw_row_t = 4
        let categories = totals(rows, by: \.categoryName)
        let categoryRows = writeTable(
            categories, title: String(localized: "Categoría"), total: total,
            sheet: sheet, startingAt: &line, formats: formats
        )
        line += 1
        writeTable(
            totals(rows, by: \.paymentMethodName), title: String(localized: "Método de pago"), total: total,
            sheet: sheet, startingAt: &line, formats: formats
        )
        line += 1
        let monthRows = writeTable(
            monthTotals(rows, locale: locale, calendar: calendar), title: String(localized: "Mes"), total: total,
            sheet: sheet, startingAt: &line, formats: formats
        )

        worksheet_set_column(sheet, 0, 0, 22, nil)
        worksheet_set_column(sheet, 1, 2, 14, nil)

        if let categoryRows {
            let chart = workbook_add_chart(workbook, UInt8(LXW_CHART_PIE.rawValue))
            let series = chart_add_series(chart, nil, nil)
            chart_series_set_categories(series, sheetName, categoryRows.first, 0, categoryRows.last, 0)
            chart_series_set_values(series, sheetName, categoryRows.first, 1, categoryRows.last, 1)
            chart_title_set_name(chart, String(localized: "Por categoría"))
            worksheet_insert_chart(sheet, 0, 4, chart)
        }
        if let monthRows {
            let chart = workbook_add_chart(workbook, UInt8(LXW_CHART_COLUMN.rawValue))
            let series = chart_add_series(chart, nil, nil)
            chart_series_set_categories(series, sheetName, monthRows.first, 0, monthRows.last, 0)
            chart_series_set_values(series, sheetName, monthRows.first, 1, monthRows.last, 1)
            chart_title_set_name(chart, String(localized: "Por mes"))
            chart_legend_set_position(chart, UInt8(LXW_CHART_LEGEND_NONE.rawValue))
            worksheet_insert_chart(sheet, 16, 4, chart)
        }
    }

    // Tabla de nombre, importe y porcentaje del total, con cabecera. Devuelve las filas de datos,
    // para los gráficos, y deja `line` en la fila siguiente a la tabla.
    @discardableResult
    private static func writeTable(
        _ totals: [(name: String, total: Decimal)],
        title: String,
        total: Decimal,
        sheet: UnsafeMutablePointer<lxw_worksheet>?,
        startingAt line: inout lxw_row_t,
        formats: Formats
    ) -> (first: lxw_row_t, last: lxw_row_t)? {
        worksheet_write_string(sheet, line, 0, title, formats.header)
        worksheet_write_string(sheet, line, 1, String(localized: "Importe"), formats.header)
        worksheet_write_string(sheet, line, 2, String(localized: "Porcentaje"), formats.header)
        line += 1
        guard !totals.isEmpty else { return nil }
        let first = line
        for item in totals {
            worksheet_write_string(sheet, line, 0, cleaned(item.name), nil)
            worksheet_write_number(sheet, line, 1, item.total.doubleValue, formats.money)
            let share = total > 0 ? (item.total / total).doubleValue : 0
            worksheet_write_number(sheet, line, 2, share, formats.percent)
            line += 1
        }
        return (first, line - 1)
    }

    // MARK: - Datos del resumen

    // De mayor a menor importe y, a igualdad, por nombre.
    private static func totals(_ rows: [ExportRow], by name: KeyPath<ExportRow, String>) -> [(name: String, total: Decimal)] {
        Dictionary(grouping: rows, by: { $0[keyPath: name] })
            .map { (name: $0.key, total: $0.value.reduce(Decimal.zero) { $0 + $1.amount }) }
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // Todos los meses del primer al último gasto, en orden y con cero los que no tienen gasto.
    private static func monthTotals(_ rows: [ExportRow], locale: Locale, calendar: Calendar) -> [(name: String, total: Decimal)] {
        guard let firstDate = rows.map(\.date).min(), let lastDate = rows.map(\.date).max() else { return [] }
        var totals: [Date: Decimal] = [:]
        for row in rows {
            totals[calendar.startOfMonth(for: row.date), default: .zero] += row.amount
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("yMMM")

        var result: [(name: String, total: Decimal)] = []
        var month = calendar.startOfMonth(for: firstDate)
        let lastMonth = calendar.startOfMonth(for: lastDate)
        while month <= lastMonth {
            result.append((formatter.string(from: month), totals[month] ?? .zero))
            guard let next = calendar.date(byAdding: .month, value: 1, to: month), next > month else { break }
            month = next
        }
        return result
    }

    // MARK: - Celdas

    private struct Formats {
        let header: UnsafeMutablePointer<lxw_format>?
        let date: UnsafeMutablePointer<lxw_format>?
        let money: UnsafeMutablePointer<lxw_format>?
        let percent: UnsafeMutablePointer<lxw_format>?

        init(workbook: UnsafeMutablePointer<lxw_workbook>, currencyFormat: String) {
            header = workbook_add_format(workbook)
            format_set_bold(header)
            // El formato 14 es la fecha corta del sistema: Excel la muestra en el formato del país
            // de quien abre el fichero.
            date = workbook_add_format(workbook)
            format_set_num_format_index(date, 14)
            money = workbook_add_format(workbook)
            format_set_num_format(money, currencyFormat)
            percent = workbook_add_format(workbook)
            format_set_num_format(percent, "0.0%")
        }
    }

    // Como fecha de Excel, que solo admite del año 1900 al 9999; fuera de ahí, como texto.
    private static func writeDate(
        _ date: Date,
        sheet: UnsafeMutablePointer<lxw_worksheet>?,
        row: lxw_row_t,
        col: lxw_col_t,
        format: UnsafeMutablePointer<lxw_format>?,
        calendar: Calendar
    ) {
        let day = date.gregorianDay(timeZone: calendar.timeZone)
        guard (1900...9999).contains(day.year) else {
            worksheet_write_string(sheet, row, col, CSVExporter.isoDay(date, calendar: calendar), nil)
            return
        }
        var value = lxw_datetime(year: Int32(day.year), month: Int32(day.month), day: Int32(day.day), hour: 0, min: 0, sec: 0)
        worksheet_write_datetime(sheet, row, col, &value, format)
    }

    // Formato de número de Excel con el símbolo de la moneda delante o detrás, como lo pone el
    // idioma del móvil: "#,##0.00 "€"" o ""US$"#,##0.00". Excel cambia los separadores al abrirlo.
    static func currencyNumberFormat(_ currency: AppCurrency, locale: Locale) -> String {
        let decimals = currency.fractionDigits > 0 ? "." + String(repeating: "0", count: currency.fractionDigits) : ""
        let number = "#,##0" + decimals
        let symbol = "\"" + currency.symbol.replacingOccurrences(of: "\"", with: "") + "\""
        let sample = Decimal(1).formatted(.currency(code: currency.rawValue).locale(locale))
        let symbolFirst = !(sample.first?.isNumber ?? false)
        return symbolFirst ? symbol + number : number + " " + symbol
    }

    // Sin caracteres de control (salvo tabulador y salto de línea): no caben en el XML del fichero y
    // Excel lo daría por dañado.
    private static func cleaned(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { $0.value >= 0x20 || $0 == "\n" || $0 == "\t" }))
    }

    private static func col(_ index: Int) -> lxw_col_t {
        lxw_col_t(index)
    }
}
