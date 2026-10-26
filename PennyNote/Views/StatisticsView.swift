import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Query(filter: #Predicate<Expense> { !$0.isSoftDeleted }, sort: \Expense.date)
    private var activeExpenses: [Expense]

    @State private var selectedMonth = SpendingStatistics.monthStart(of: .now)

    private static let evolutionMonthCount = 6

    private var isCurrentMonth: Bool {
        selectedMonth >= SpendingStatistics.monthStart(of: .now)
    }

    var body: some View {
        let monthExpenses = SpendingStatistics.expenses(activeExpenses, inMonthOf: selectedMonth)
        let spending = SpendingStatistics.monthSpending(monthExpenses, monthOf: selectedMonth)
        let elapsedDays = SpendingStatistics.elapsedDays(inMonthOf: selectedMonth)

        List {
            Section {
                monthSelector
                summary(spending: spending, elapsedDays: elapsedDays)
            }

            if monthExpenses.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Sin gastos",
                        systemImage: "chart.bar",
                        description: Text("No hay gastos en \(DisplayFormat.monthAndYear(selectedMonth).lowercased()).")
                    )
                }
            } else {
                Section("Gasto diario") {
                    DailySpendingChart(spending: spending, elapsedDays: elapsedDays)
                        // Nueva identidad por mes: el día seleccionado no se arrastra al cambiar de mes.
                        .id(selectedMonth)
                }

                Section("Por categoría") {
                    categoryRows(for: monthExpenses)
                }

                Section("Por método de pago") {
                    paymentMethodRows(for: monthExpenses)
                }
            }

            Section("Evolución") {
                MonthlyEvolutionChart(
                    totals: SpendingStatistics.monthlyTotals(
                        activeExpenses,
                        endingInMonthOf: selectedMonth,
                        count: Self.evolutionMonthCount
                    ),
                    selectedMonth: $selectedMonth
                )
            }
        }
        .navigationTitle("Estadísticas")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthSelector: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Mes anterior")

            Spacer()
            Text(DisplayFormat.monthAndYear(selectedMonth))
                .font(.headline)
                .contentTransition(.numericText())
            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isCurrentMonth)
            .accessibilityLabel("Mes siguiente")
        }
        // Sin esto, en una fila de List un toque en cualquier botón dispara los dos.
        .buttonStyle(.borderless)
    }

    private func summary(spending: MonthSpending, elapsedDays: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DisplayFormat.currency(spending.total))
                .font(.system(size: 34, weight: .bold, design: .rounded))
            if elapsedDays > 0 {
                // Igual que la línea de media de la gráfica: sin contar gastos con fecha futura.
                Text("Media diaria: \(DisplayFormat.currency(spending.total(throughDay: elapsedDays) / Decimal(elapsedDays)))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func categoryRows(for monthExpenses: [Expense]) -> some View {
        let totals = SpendingStatistics.categoryTotals(monthExpenses)
        let monthTotal = totals.reduce(Decimal.zero) { $0 + $1.total }
        return ForEach(totals) { item in
            let name = item.category?.name ?? ExpenseCategory.uncategorizedLabel
            NavigationLink {
                FilteredExpensesView(title: name, month: selectedMonth, filter: filter(for: item.category))
            } label: {
                SpendingShareRow(
                    title: name,
                    symbolName: item.category?.symbolName ?? ExpenseCategory.uncategorizedSymbolName,
                    color: item.category?.displayColor ?? CategoryColor.neutral,
                    total: item.total,
                    fraction: fraction(of: item.total, in: monthTotal)
                )
            }
        }
    }

    private func paymentMethodRows(for monthExpenses: [Expense]) -> some View {
        let totals = SpendingStatistics.paymentMethodTotals(monthExpenses)
        let monthTotal = totals.reduce(Decimal.zero) { $0 + $1.total }
        return ForEach(totals) { item in
            NavigationLink {
                FilteredExpensesView(
                    title: item.paymentMethod.rawValue,
                    month: selectedMonth,
                    filter: ExpenseFilter(paymentMethods: [item.paymentMethod])
                )
            } label: {
                SpendingShareRow(
                    title: item.paymentMethod.rawValue,
                    symbolName: item.paymentMethod.symbolName,
                    color: .accentColor,
                    total: item.total,
                    fraction: fraction(of: item.total, in: monthTotal)
                )
            }
        }
    }

    private func filter(for category: ExpenseCategory?) -> ExpenseFilter {
        guard let category else { return ExpenseFilter(includesUncategorized: true) }
        return ExpenseFilter(categoryIDs: [category.id])
    }

    private func fraction(of amount: Decimal, in total: Decimal) -> Double {
        total > 0 ? (amount / total).doubleValue : 0
    }

    private func moveMonth(by months: Int) {
        guard let month = Calendar.current.date(byAdding: .month, value: months, to: selectedMonth) else { return }
        withAnimation(.snappy) {
            selectedMonth = min(month, SpendingStatistics.monthStart(of: .now))
        }
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
}
