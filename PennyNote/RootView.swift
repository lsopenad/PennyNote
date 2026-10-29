import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AccountSession.self) private var session
    @Environment(CurrencySettings.self) private var currencySettings
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
            .sheet(item: sheetBinding) { sheet in
                switch sheet {
                case .addExpense:
                    AddEditExpenseView(expense: router.expenseToEdit)
                case .currencyChoice:
                    CurrencyChoiceView(suggestion: currencySettings.currency)
                }
            }
            .onOpenURL { url in
                DeepLinkHandler.handle(url, router: router)
            }
            .onReceive(NotificationCenter.default.publisher(for: .pennyNoteOpenAddExpense)) { _ in
                router.presentAdd()
            }
            // Al final para que también llegue a las hojas.
            .environment(\.currency, currencySettings.currency)
    }

    // Una sola hoja: con dos, la de elegir moneda no se presentaría si la de añadir ya está abierta.
    // Elegir moneda tiene prioridad; si se estaba añadiendo un gasto, la hoja vuelve después.
    private enum RootSheet: Identifiable {
        case addExpense
        case currencyChoice

        var id: Self { self }
    }

    private var sheetBinding: Binding<RootSheet?> {
        Binding(
            get: {
                if currencySettings.needsChoice { return .currencyChoice }
                return router.isAddExpensePresented ? .addExpense : nil
            },
            // La de moneda solo se cierra al elegir (CurrencySettings.choose), no deslizando la hoja.
            set: { if $0 == nil, !currencySettings.needsChoice { router.isAddExpensePresented = false } }
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
                .environment(\.currency, .regionDefault())
                .modelContainer(container)
        } else {
            ProgressView()
                .onAppear { container = DemoData.makeContainer() }
        }
    }
}
