import SwiftUI

struct SettingsView: View {
    @Environment(AccountSession.self) private var session
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
}
