import SwiftUI

// Se muestra una vez por cuenta, cuando el servidor confirma que aún no tiene moneda.
struct CurrencyChoiceView: View {
    @Environment(CurrencySettings.self) private var currencySettings
    @Environment(SyncCoordinator.self) private var sync

    @State private var selection: AppCurrency

    init(suggestion: AppCurrency) {
        _selection = State(initialValue: suggestion)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CurrencyPicker(selection: $selection)
                } footer: {
                    Text("Tus gastos se mostrarán en esta moneda. Puedes cambiarla en Ajustes.")
                }
            }
            .navigationTitle("Elige tu moneda")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continuar") {
                        currencySettings.choose(selection)
                        sync.requestSync()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
