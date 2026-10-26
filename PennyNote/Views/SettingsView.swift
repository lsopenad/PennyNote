import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink("Categorías") {
                    CategoryManagementView()
                }
            }
        }
        .navigationTitle("Ajustes")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
