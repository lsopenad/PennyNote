import SwiftUI

struct SettingsView: View {
    @Environment(AccountSession.self) private var session
    @Environment(CurrencySettings.self) private var currencySettings
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                NavigationLink("Categorías") {
                    CategoryManagementView()
                }
            }

            Section {
                // El idioma se elige en los Ajustes de iOS (PennyNote → Idioma): así cambian también los
                // widgets, Siri y Atajos, que no comparten un ajuste propio de la app.
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    LabeledContent("Idioma", value: Self.currentLanguageName)
                }
                .foregroundStyle(.primary)
            } footer: {
                Text("Se cambia en los Ajustes de iOS. Por defecto, la app usa el idioma del iPhone.")
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

    // "Español", "English", "简体中文": el idioma en que se está mostrando la app, en ese idioma.
    private static var currentLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        let name = Locale(identifier: code).localizedString(forIdentifier: code) ?? code
        return name.prefix(1).uppercased() + name.dropFirst()
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
