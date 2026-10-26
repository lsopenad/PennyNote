import SwiftUI

// Secciones de Ajustes para la cuenta: estado de la sincronización, cerrar sesión y borrar la cuenta.
struct AccountSettingsSections: View {
    @Environment(AccountSession.self) private var session
    @Environment(SyncCoordinator.self) private var sync

    @State private var isSignOutConfirmationPresented = false
    @State private var unsyncedChangeCount: Int?
    @State private var isDeleteConfirmationPresented = false
    @State private var operation = AccountOperation()

    var body: some View {
        Section("Cuenta") {
            LabeledContent("Email", value: session.userEmail ?? "")
            NavigationLink("Cambiar contraseña") {
                ChangePasswordView()
            }
            syncStatusRow
            Button("Sincronizar ahora") {
                Task { await sync.syncNow() }
            }
            .disabled(sync.isSyncing || operation.isWorking)
        }

        Section {
            Button("Cerrar sesión") {
                isSignOutConfirmationPresented = true
            }
            .disabled(operation.isWorking)
        } footer: {
            Text("Tus gastos siguen en tu cuenta y se borran de este iPhone.")
        }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $isSignOutConfirmationPresented, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { signOut(discardingPendingChanges: false) }
        }
        .alert(
            "Hay cambios sin guardar en tu cuenta",
            isPresented: Binding(get: { unsyncedChangeCount != nil }, set: { if !$0 { unsyncedChangeCount = nil } })
        ) {
            Button("Cerrar sesión igualmente", role: .destructive) { signOut(discardingPendingChanges: true) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("\(unsyncedChangeCount ?? 0) cambios no se han podido subir. Si cierras sesión ahora se perderán. Prueba antes a sincronizar con conexión a internet.")
        }

        Section {
            Button("Borrar mi cuenta y mis datos", role: .destructive) {
                isDeleteConfirmationPresented = true
            }
            .disabled(operation.isWorking)
        } footer: {
            Text("Borra la cuenta y todos sus gastos y categorías, del servidor y de este iPhone. No se puede deshacer.")
        }
        .confirmationDialog(
            "¿Borrar tu cuenta y todos tus datos?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Borrar cuenta y datos", role: .destructive, action: deleteAccount)
        } message: {
            Text("Se borrarán todos tus gastos y categorías. No se puede deshacer.")
        }
        .alert(
            "No se ha podido completar",
            isPresented: Binding(get: { operation.errorMessage != nil }, set: { if !$0 { operation.errorMessage = nil } })
        ) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(operation.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var syncStatusRow: some View {
        if sync.isSyncing || operation.isWorking {
            LabeledContent("Sincronización") { ProgressView() }
        } else {
            LabeledContent("Sincronización") {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(syncSummary)
                    if let lastErrorMessage = sync.lastErrorMessage {
                        Text(lastErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .multilineTextAlignment(.trailing)
            }
        }
    }

    private var syncSummary: String {
        if sync.pendingChangeCount > 0 {
            return sync.pendingChangeCount == 1 ? "1 cambio pendiente" : "\(sync.pendingChangeCount) cambios pendientes"
        }
        guard let lastSyncDate = sync.lastSyncDate else { return "Pendiente" }
        return "Al día, \(lastSyncDate.formatted(.relative(presentation: .named)))"
    }

    private func signOut(discardingPendingChanges: Bool) {
        operation.run { [session, operation] in
            switch await session.signOut(discardingPendingChanges: discardingPendingChanges) {
            case .signedOut:
                break
            case .pendingChanges(let count):
                unsyncedChangeCount = count
            case .failed(let message):
                operation.errorMessage = message
            }
        }
    }

    private func deleteAccount() {
        operation.run { [session] in
            try await session.deleteAccount()
        }
    }
}
