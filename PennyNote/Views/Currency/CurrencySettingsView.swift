import SwiftUI

// Ajustes → Moneda. Cada cambio se guarda en el acto y se sincroniza con la cuenta.
struct CurrencySettingsView: View {
    @Environment(CurrencySettings.self) private var currencySettings
    @Environment(SyncCoordinator.self) private var sync

    @State private var selection: AppCurrency

    init(currency: AppCurrency) {
        _selection = State(initialValue: currency)
    }

    var body: some View {
        List {
            Section {
                CurrencyPicker(selection: $selection)
            } footer: {
                Text("Los importes no se convierten: solo cambia cómo se muestran.")
            }
        }
        .navigationTitle("Moneda")
        .onChange(of: selection) { _, newValue in
            guard newValue != currencySettings.currency else { return }
            currencySettings.choose(newValue)
            sync.requestSync()
        }
        // La que llegue de otro dispositivo mientras la pantalla está abierta.
        .onChange(of: currencySettings.currency) { _, newValue in
            selection = newValue
        }
    }
}
