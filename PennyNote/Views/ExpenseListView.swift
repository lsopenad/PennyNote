import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]

    private var expenses: [Expense] {
        allExpenses.filter { !$0.isDeleted }
    }

    private var groupedExpenses: [(day: Date, items: [Expense])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
        return groups
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, items: $0.value) }
    }

    private var monthlyTotal: Decimal {
        MonthlyTotalCalculator.total(in: modelContext)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    Section {
                        MonthHeaderView(total: monthlyTotal)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }

                    ForEach(groupedExpenses, id: \.day) { group in
                        Section(header: Text(group.day, style: .date)) {
                            ForEach(group.items) { expense in
                                ExpenseRowView(expense: expense)
                                    .contentShape(Rectangle())
                                    .onTapGesture { router.presentEdit(expense) }
                            }
                            .onDelete { offsets in delete(group.items, at: offsets) }
                        }
                    }
                }
                .listStyle(.plain)

                Button(action: { router.presentAdd() }) {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(.tint, in: Circle())
                        .shadow(radius: 4, y: 2)
                }
                .padding(20)
            }
            .navigationTitle("PennyNote")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    private func delete(_ items: [Expense], at offsets: IndexSet) {
        for index in offsets {
            ExpenseRepository.deleteExpense(items[index], context: modelContext)
        }
    }
}
