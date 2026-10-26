import Foundation
import Observation
import Supabase

// Estado de la sesión de Supabase y las operaciones de cuenta. La app solo se usa con sesión
// iniciada; los datos siguen en el móvil y se sincronizan con la cuenta.
@MainActor
@Observable
final class AccountSession {
    static let shared = AccountSession()

    enum State: Equatable {
        // Falta Config/Supabase.xcconfig al compilar.
        case unconfigured
        case loading
        case signedOut
        case signedIn(userID: UUID, email: String)
        // Sin sesión, con datos de ejemplo en memoria y en solo lectura (DemoData).
        case demo
    }

    enum SignOutOutcome: Equatable {
        case signedOut
        // Cambios que no se han podido subir y se perderían al borrar los datos del móvil.
        case pendingChanges(Int)
        case failed(message: String)
    }

    private(set) var state: State

    @ObservationIgnored private let client: SupabaseClient?
    @ObservationIgnored private let sync: SyncCoordinator

    init(client: SupabaseClient? = SupabaseBackend.client) {
        self.client = client
        sync = .shared
        state = client == nil ? .unconfigured : .loading
        if let client {
            listenForAuthChanges(client)
        }
    }

    var userEmail: String? {
        if case .signedIn(_, let email) = state { email } else { nil }
    }

    // Solo desde la pantalla de inicio de sesión: la demo no toca la cuenta ni el almacén compartido.
    func enterDemo() {
        guard state == .signedOut else { return }
        state = .demo
    }

    func exitDemo() {
        guard state == .demo else { return }
        state = .signedOut
    }

    func signIn(email: String, password: String) async throws {
        try await requireClient().auth.signIn(email: Self.normalized(email), password: password)
    }

    func signUp(email: String, password: String) async throws {
        let response = try await requireClient().auth.signUp(email: Self.normalized(email), password: password)
        // Sin sesión es que el proyecto de Supabase pide confirmar el email (no debería: se desactiva).
        if response.session == nil {
            throw AccountError.emailConfirmationRequired
        }
    }

    // Solo con sesión iniciada. No hay recuperación por email (el proyecto no tiene SMTP): una
    // contraseña olvidada la restablece quien administra Supabase y el usuario la cambia aquí.
    func updatePassword(_ password: String) async throws {
        let client = try requireClient()
        try await client.auth.update(user: UserAttributes(password: password))
        // Si se cambia porque alguien más tenía acceso, sus sesiones dejan de valer; esta sigue abierta.
        do {
            try await client.auth.signOut(scope: .others)
        } catch {
            Log.auth.error("Fallo al cerrar las otras sesiones tras cambiar la contraseña: \(error.localizedDescription)")
        }
    }

    // Sube lo pendiente y, si no queda nada (o se acepta perderlo), borra los datos del móvil y sale.
    func signOut(discardingPendingChanges: Bool) async -> SignOutOutcome {
        if !discardingPendingChanges {
            await sync.syncNow()
            let unsynced = sync.unsyncedChangeCount()
            if unsynced > 0 {
                return .pendingChanges(unsynced)
            }
        }
        do {
            try await sync.deactivateAndWipeLocalData()
        } catch {
            Log.sync.error("Fallo al borrar los datos locales al cerrar sesión: \(error.localizedDescription)")
            return .failed(message: "No se han podido borrar los datos de este iPhone. Inténtalo de nuevo.")
        }
        await signOutLocally()
        return .signedOut
    }

    // Borra el usuario en el servidor (y en cascada sus datos) y después lo de este móvil.
    func deleteAccount() async throws {
        try await requireClient().rpc("delete_my_account").execute()
        do {
            try await sync.deactivateAndWipeLocalData()
        } catch {
            // La cuenta ya no existe: se sale igualmente. Si luego entra otra cuenta, SyncEngine ve que
            // los datos no son suyos y los borra antes de sincronizar.
            Log.sync.error("Fallo al borrar los datos locales tras borrar la cuenta: \(error.localizedDescription)")
        }
        await signOutLocally()
    }

    // MARK: - Privado

    private func listenForAuthChanges(_ client: SupabaseClient) {
        Task { [weak self] in
            for await (_, session) in client.auth.authStateChanges {
                self?.apply(session)
            }
        }
    }

    private func apply(_ session: Session?) {
        let previousUserID = signedInUserID
        if let session {
            state = .signedIn(userID: session.user.id, email: session.user.email ?? "")
        } else if state != .demo {
            // Un aviso sin sesión (p. ej. al caducar el token guardado) no saca de la demo.
            state = .signedOut
        }

        guard let userID = signedInUserID else {
            // También sin sesión previa en esta ejecución (p. ej. revocada con la app cerrada): la marca
            // de sesión activa que consulta LogExpenseIntent puede venir de la ejecución anterior.
            sync.deactivate()
            return
        }
        guard userID != previousUserID, let client else { return }
        Task { await sync.activate(userID: userID, remote: SupabaseSyncRemote(client: client)) }
    }

    private var signedInUserID: UUID? {
        if case .signedIn(let userID, _) = state { userID } else { nil }
    }

    // Solo esta sesión: cerrar sesión en el iPhone no debe echar a la cuenta de otros dispositivos.
    private func signOutLocally() async {
        do {
            try await client?.auth.signOut(scope: .local)
        } catch {
            // El SDK borra la sesión guardada antes de avisar al servidor: aunque falle la red, se sale.
            Log.auth.error("Fallo al avisar al servidor del cierre de sesión: \(error.localizedDescription)")
        }
    }

    private func requireClient() throws -> SupabaseClient {
        guard let client else { throw AccountError.notConfigured }
        return client
    }

    private static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum AccountError: Error {
    case notConfigured
    case emailConfirmationRequired
}
