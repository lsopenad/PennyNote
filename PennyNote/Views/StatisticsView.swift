import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.currency) private var currency

    @Query(filter: #Predicate<Expense> { !$0.isSoftDeleted }, sort: \Expense.date)
    private var activeExpenses: [Expense]

    // Siempre se entra en el mes actual; el modo no se recuerda entre visitas.
    @State private var kind = StatisticsPeriod.Kind.month
    @State private var period = StatisticsPeriod(kind: .month, containing: .now)

    private static let evolutionMonthCount = 6
    private static let evolutionWeekCount = 8

    private var latestPeriod: StatisticsPeriod {
        SpendingStatistics.latestPeriod(period.kind, expenses: activeExpenses)
    }

    var body: some View {
        let periodExpenses = SpendingStatistics.expenses(activeExpenses, in: period)
        let elapsedDays = SpendingStatistics.elapsedDays(in: period)

        List {
            Section {
                Picker("Periodo", selection: $kind) {
                    ForEach(StatisticsPeriod.Kind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                periodSelector
                summary(for: periodExpenses, elapsedDays: elapsedDays)
            }

            if periodExpenses.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Sin gastos",
                        systemImage: "chart.bar",
                        description: Text(emptyDescription)
                    )
                }
            } else {
                if period.kind == .day {
                    Section("Gastos") {
                        dayExpenseRows(for: periodExpenses)
                    }
                } else {
                    Section("Gasto diario") {
                        DailySpendingChart(
                            days: period.days(),
                            dailyTotals: SpendingStatistics.dailyTotals(periodExpenses, in: period),
                            elapsedDays: elapsedDays
                        )
                        // Nueva identidad por periodo: el día seleccionado no se arrastra al cambiar.
                        .id(period)
                    }
                }

                Section("Por categoría") {
                    categoryRows(for: periodExpenses)
                }

                Section("Por método de pago") {
                    paymentMethodRows(for: periodExpenses)
                }
            }

            if let evolutionCount {
                Section("Evolución") {
                    PeriodEvolutionChart(
                        totals: SpendingStatistics.periodTotals(activeExpenses, endingIn: period, count: evolutionCount),
                        selection: $period
                    )
                }
            }
        }
        .navigationTitle("Estadísticas")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: kind) { _, newKind in
            withAnimation(.snappy) {
                period = period.converted(to: newKind)
            }
        }
    }

    // Por días no hay evolución: la semana ya se ve en modo Semana.
    private var evolutionCount: Int? {
        switch period.kind {
        case .month: Self.evolutionMonthCount
        case .week: Self.evolutionWeekCount
        case .day: nil
        }
    }

    private var emptyDescription: LocalizedStringResource {
        switch period.kind {
        case .month: "No hay gastos en este mes."
        case .week: "No hay gastos en esta semana."
        case .day: "No hay gastos este día."
        }
    }

    private var periodSelector: some View {
        HStack {
            Button {
                move(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Anterior")

            Spacer()
            Text(period.title())
                .font(.headline)
                .contentTransition(.numericText())
            Spacer()

            Button {
                move(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(period.start >= latestPeriod.start)
            .accessibilityLabel("Siguiente")
        }
        // Sin esto, en una fila de List un toque en cualquier botón dispara los dos.
        .buttonStyle(.borderless)
    }

    private func summary(for periodExpenses: [Expense], elapsedDays: Int) -> some View {
        let total = periodExpenses.sum(of: \.amount)
        return VStack(alignment: .leading, spacing: 4) {
            Text(DisplayFormat.currency(total, in: currency))
                .font(.system(size: 34, weight: .bold, design: .rounded))
            if period.kind == .day {
                Text("\(periodExpenses.count) gastos")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if elapsedDays > 0 {
                // Igual que la línea de media de la gráfica: sin contar gastos con fecha futura.
                let elapsedTotal = SpendingStatistics.dailyTotals(periodExpenses, in: period).prefix(elapsedDays).sum(of: { $0 })
                Text("Media diaria: \(DisplayFormat.currency(elapsedTotal / Decimal(elapsedDays), in: currency))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Del más reciente al más antiguo, como en la lista principal.
    private func dayExpenseRows(for dayExpenses: [Expense]) -> some View {
        ForEach(dayExpenses.reversed()) { expense in
            ExpenseRowView(expense: expense)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isReadOnly else { return }
                    router.presentEdit(expense)
                }
        }
    }

    private func categoryRows(for periodExpenses: [Expense]) -> some View {
        let totals = SpendingStatistics.categoryTotals(periodExpenses)
        let periodTotal = totals.sum(of: \.total)
        return ForEach(totals) { item in
            let name = item.category.displayName
            NavigationLink {
                FilteredExpensesView(title: name, period: period, filter: filter(for: item.category))
            } label: {
                SpendingShareRow(
                    title: name,
                    symbolName: item.category.displaySymbolName,
                    color: item.category.displayColor,
                    total: item.total,
                    fraction: fraction(of: item.total, in: periodTotal)
                )
            }
        }
    }

    private func paymentMethodRows(for periodExpenses: [Expense]) -> some View {
        let totals = SpendingStatistics.paymentMethodTotals(periodExpenses)
        let periodTotal = totals.sum(of: \.total)
        return ForEach(totals) { item in
            NavigationLink {
                FilteredExpensesView(
                    title: String(localized: item.paymentMethod.title),
                    period: period,
                    filter: ExpenseFilter(paymentMethods: [item.paymentMethod])
                )
            } label: {
                SpendingShareRow(
                    title: String(localized: item.paymentMethod.title),
                    symbolName: item.paymentMethod.symbolName,
                    color: .accentColor,
                    total: item.total,
                    fraction: fraction(of: item.total, in: periodTotal)
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

    private func move(by offset: Int) {
        let latest = latestPeriod
        let moved = period.moved(by: offset)
        withAnimation(.snappy) {
            period = moved.start > latest.start ? latest : moved
        }
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
    .environment(AppRouter())
}
