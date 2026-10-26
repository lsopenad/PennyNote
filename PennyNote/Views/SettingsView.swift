import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink("Categorías") {
                    CategoryManagementView()
                }
            }

            AccountSettingsSections()
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
