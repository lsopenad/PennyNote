import SwiftUI

struct SettingsView: View {
    @Environment(AccountSession.self) private var session
    @Environment(CurrencySettings.self) private var currencySettings
    @Environment(\.isReadOnly) private var isReadOnly

    var body: some View {
        List {
            Section {
                NavigationLink("Categorías") {
                    CategoryManagementView()
                }
            }

            if isReadOnly {
                Section {
                    Button("Salir de la demo", action: session.exitDemo)
                } footer: {
                    Text("Estás viendo datos de ejemplo. No se pueden modificar y no se guardan.")
                }
            } else {
                Section {
                    NavigationLink {
                        CurrencySettingsView(currency: currencySettings.currency)
                    } label: {
                        LabeledContent("Moneda", value: currencySettings.currency.displayName)
                    }
                }
                AccountSettingsSections()
            }
        }
        .navigationTitle("Ajustes")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AccountSession(client: nil))
    .environment(SyncCoordinator.shared)
    .environment(CurrencySettings.shared)
}
