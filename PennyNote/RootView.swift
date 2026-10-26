import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AccountSession.self) private var session
    @State private var router = AppRouter()

    var body: some View {
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
        case .demo:
            DemoRootView()
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

// Modo demo: la misma pantalla principal sobre un almacén en memoria y en solo lectura. Sin hoja de
// añadir ni enlaces profundos, y fuera del contenedor compartido, que es el que lee el widget.
private struct DemoRootView: View {
    // Se crea al aparecer y no como valor inicial del @State: ese se evaluaría (y generaría los datos)
    // cada vez que RootView vuelve a crear esta vista.
    @State private var container: ModelContainer?
    @State private var router = AppRouter()

    var body: some View {
        if let container {
            ExpenseListView()
                .environment(router)
                .environment(\.isReadOnly, true)
                .modelContainer(container)
        } else {
            ProgressView()
                .onAppear { container = DemoData.makeContainer() }
        }
    }
}
