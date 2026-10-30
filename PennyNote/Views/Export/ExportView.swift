import SwiftUI
import SwiftData

// Ajustes → Exportar: los gastos de un periodo en Excel o CSV, con la hoja de compartir de iOS.
struct ExportView: View {
    @Environment(\.currency) private var currency

    @Query(filter: #Predicate<Expense> { !$0.isSoftDeleted }, sort: \Expense.date)
    private var activeExpenses: [Expense]

    @State private var range = ExportRange.thisMonth
    @State private var format = ExportFormat.excel
    @State private var customStart = Calendar.current.startOfMonth(for: .now)
    @State private var customEnd = Date.now

    var body: some View {
        let interval = range.interval(from: customStart, to: customEnd)
        let expenses = interval.map { interval in activeExpenses.filter { interval.includesExportDate($0.date) } } ?? activeExpenses

        Form {
            Section {
                Picker("Periodo", selection: $range) {
                    ForEach(ExportRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }

                if range == .custom {
                    DatePicker("Desde", selection: $customStart, in: ...customEnd, displayedComponents: .date)
                    DatePicker("Hasta", selection: $customEnd, in: customStart..., displayedComponents: .date)
                }
            }

            Section {
                Picker("Formato", selection: $format) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(verbatim: format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Formato")
            } footer: {
                switch format {
                case .excel: Text("Una hoja con los gastos y otra con el resumen por categoría, método de pago y mes, con gráficos.")
                case .csv: Text("Texto con los gastos separados por comas, para abrirlo en cualquier hoja de cálculo.")
                }
            }

            Section {
                ShareLink(
                    item: exportFile(for: expenses, interval: interval),
                    preview: SharePreview(range.fileName(for: interval))
                ) {
                    Label("Exportar", systemImage: "square.and.arrow.up")
                }
                .disabled(expenses.isEmpty)
            } footer: {
                if expenses.isEmpty {
                    Text("No hay gastos en este periodo.")
                } else {
                    Text("\(expenses.count) gastos")
                }
            }
        }
        .navigationTitle("Exportar")
        .task {
            ExportFile.removeTemporaryFiles()
        }
    }

    private func exportFile(for expenses: [Expense], interval: DateInterval?) -> ExportFile {
        ExportFile(
            rows: ExportRow.rows(for: expenses),
            format: format,
            currency: currency,
            fileName: range.fileName(for: interval),
            periodTitle: range.periodTitle(for: interval)
        )
    }
}

#Preview {
    NavigationStack {
        ExportView()
    }
    .modelContainer(for: [Expense.self, ExpenseCategory.self, RecurringExpense.self], inMemory: true)
}
