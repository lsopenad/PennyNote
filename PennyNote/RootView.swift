import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var router = AppRouter()

    var body: some View {
        ExpenseListView()
            .environment(router)
            .sheet(isPresented: routerAddBinding) {
                AddEditExpenseView(expense: router.expenseToEdit)
            }
            .task {
                LegacyNotionCleanup.runIfNeeded()
                SeedDataService.seedIfNeeded(context: modelContext)
                SeedDataService.assignMissingColors(context: modelContext)
                MonthlyTotalCalculator.refreshWidgetSnapshot(in: modelContext)
            }
            .onOpenURL { url in
                DeepLinkHandler.handle(url, router: router)
            }
            .onReceive(NotificationCenter.default.publisher(for: .pennyNoteOpenAddExpense)) { _ in
                router.presentAdd()
            }
    }

    private var routerAddBinding: Binding<Bool> {
        Binding(
            get: { router.isAddExpensePresented },
            set: { router.isAddExpensePresented = $0 }
        )
    }
}
