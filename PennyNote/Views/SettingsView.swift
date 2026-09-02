import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var tokenText: String = NotionCredentialsStore.token ?? ""
    @State private var parentPageText: String = ""
    @State private var statusMessage: String?
    @State private var isBusy = false
    @State private var isConnected: Bool = SyncStateStore.notionDatabaseID != nil

    var body: some View {
        List {
            Section("Notion") {
                SecureField("Token de integración", text: $tokenText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: tokenText) { _, newValue in
                        NotionCredentialsStore.token = newValue.isEmpty ? nil : newValue
                    }

                TextField("URL o ID de la página padre", text: $parentPageText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Probar conexión") { Task { await testConnection() } }
                    .disabled(tokenText.isEmpty || isBusy)

                if isConnected {
                    Label("Conectado a Notion", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Conectar con Notion") { Task { await connect() } }
                        .disabled(tokenText.isEmpty || parentPageText.isEmpty || isBusy)
                }

                Button("Sincronizar ahora") { Task { await sync() } }
                    .disabled(!isConnected || isBusy)

                if let lastSyncDate = SyncStateStore.lastSyncDate {
                    Text("Última sincronización: \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                NavigationLink("Categorías") {
                    CategoryManagementView()
                }
            }
        }
        .navigationTitle("Ajustes")
    }

    private func testConnection() async {
        guard let token = NotionCredentialsStore.token else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await NotionClient(token: token).verifyConnection()
            statusMessage = "Conexión correcta."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func connect() async {
        guard let token = NotionCredentialsStore.token,
              let parentPageID = NotionPageIDParser.parse(parentPageText)
        else {
            statusMessage = "No se pudo interpretar la página padre."
            return
        }

        isBusy = true
        defer { isBusy = false }
        do {
            let names = categories.map(\.name)
            let databaseID = try await NotionClient(token: token).createDatabase(parentPageID: parentPageID, categoryNames: names)
            SyncStateStore.notionDatabaseID = databaseID
            isConnected = true
            statusMessage = "Base de datos creada en Notion."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func sync() async {
        isBusy = true
        defer { isBusy = false }
        await SyncEngine.shared.syncNow()
        statusMessage = SyncStateStore.lastSyncError ?? "Sincronizado."
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
