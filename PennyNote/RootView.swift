import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var session
    @State private var router = AppRouter()

    var body: some View {
        content
            .task {
                LegacyNotionCleanup.runIfNeeded()
                SeedDataService.assignMissingColors(context: modelContext)
                MonthlyTotalCalculator.refreshWidgetSnapshot(in: modelContext)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .unconfigured:
            ContentUnavailableView(
                "Falta configurar el servidor",
                systemImage: "exclamationmark.icloud",
                description: Text("Esta compilación no incluye la configuración de Supabase (Config/Supabase.xcconfig).")
            )
        case .loading:
            ProgressView()
        case .signedOut:
            AuthView()
        case .signedIn:
            mainContent
        }
    }

    private var mainContent: some View {
        ExpenseListView()
            .environment(router)
            .sheet(isPresented: routerAddBinding) {
                AddEditExpenseView(expense: router.expenseToEdit)
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
