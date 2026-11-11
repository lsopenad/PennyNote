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
            if SharedModelContainer.isInMemoryFallback {
                // Lo que se apuntara aquí se perdería al cerrar la app.
                ContentUnavailableView(
                    "No se han podido abrir tus datos",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Cierra PennyNote del todo y vuelve a abrirla. Tus gastos no se han perdido: siguen en este iPhone y en tu cuenta.")
                )
            } else {
                mainContent
            }
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
