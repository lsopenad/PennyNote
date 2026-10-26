import Foundation
import Observation
import SwiftData

// Decide cuándo se sincroniza y publica el estado para Ajustes. Solo hay una pasada a la vez: lo que
// se pide mientras otra está en marcha se junta en una única pasada más al terminar.
@MainActor
@Observable
final class SyncCoordinator {
    static let shared = SyncCoordinator()

    // Espera tras un cambio antes de subirlo, para juntar en una pasada varios cambios seguidos.
    private static let debounceDelay: Duration = .seconds(2)

    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var lastErrorMessage: String?
    private(set) var pendingChangeCount = 0

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let state: SyncStateStore
    @ObservationIgnored private var engine: SyncEngine?
    // Usuario con sesión: si preparar sus datos falla, se reintenta en la siguiente sincronización.
    @ObservationIgnored private var activeUser: (id: UUID, remote: SyncRemote)?
    @ObservationIgnored private var currentPass: Task<Void, Never>?
    @ObservationIgnored private var needsAnotherPass = false
    @ObservationIgnored private var debounceTask: Task<Void, Never>?

    private init() {
        container = SharedModelContainer.container
        state = .standard
        lastSyncDate = state.lastSyncDate
    }

    // Al iniciar sesión (o abrir la app con la sesión guardada).
    func activate(userID: UUID, remote: SyncRemote) async {
        activeUser = (userID, remote)
        engine = nil
        lastSyncDate = state.lastSyncDate
        await syncNow()
    }

    // Crea el motor la primera vez que hace falta tras activate, una vez preparados los datos locales.
    private func readyEngine() -> SyncEngine? {
        if let engine { return engine }
        guard let activeUser else { return nil }
        let engine = SyncEngine(context: container.mainContext, remote: activeUser.remote, state: state)
        do {
            try engine.prepareLocalData(for: activeUser.id)
        } catch {
            Log.sync.error("Fallo al preparar los datos locales para la sesión: \(error.localizedDescription)")
            lastErrorMessage = "No se han podido preparar los datos de este iPhone para tu cuenta."
            return nil
        }
        self.engine = engine
        return engine
    }

    // Deja de sincronizar sin tocar los datos (sesión caducada o revocada): si se vuelve a entrar con
    // la misma cuenta, lo pendiente se sube entonces.
    func deactivate() {
        debounceTask?.cancel()
        debounceTask = nil
        engine = nil
        activeUser = nil
        lastErrorMessage = nil
    }

    // Al cerrar sesión o borrar la cuenta: espera a la pasada en curso y borra los datos del móvil.
    func deactivateAndWipeLocalData() async throws {
        deactivate()
        await currentPass?.value
        try SyncEngine.wipeLocalData(context: container.mainContext, state: state)
        lastSyncDate = nil
        pendingChangeCount = 0
    }

    // Tras un cambio local.
    func requestSync() {
        guard activeUser != nil else { return }
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: Self.debounceDelay)
            guard !Task.isCancelled else { return }
            await syncNow()
        }
    }

    func syncNow() async {
        if let currentPass {
            needsAnotherPass = true
            await currentPass.value
            return
        }
        let pass = Task {
            repeat {
                needsAnotherPass = false
                await runPass()
            } while needsAnotherPass && activeUser != nil
            // Aquí y no tras el await de quien la lanzó: así nadie ve una pasada ya terminada como
            // en curso y deja su petición sin atender.
            currentPass = nil
        }
        currentPass = pass
        await pass.value
    }

    // Cambios sin subir según lo guardado, aunque la sincronización no haya llegado a arrancar.
    func unsyncedChangeCount() -> Int {
        SyncEngine.pendingChangeCount(context: container.mainContext, state: state)
    }

    private func runPass() async {
        guard let engine = readyEngine() else { return }
        isSyncing = true
        defer {
            isSyncing = false
            // Lo bajado del servidor puede cambiar el gasto del mes.
            WidgetSnapshotRefresher.refresh(in: container.mainContext)
        }
        do {
            pendingChangeCount = try await engine.sync()
            lastSyncDate = state.lastSyncDate
            lastErrorMessage = nil
        } catch {
            // Si la pasada se corta a medias no se sabe cuánto ha subido: se cuenta en el almacén.
            pendingChangeCount = unsyncedChangeCount()
            guard !(error is CancellationError) else { return }
            Log.sync.error("Fallo al sincronizar: \(error.localizedDescription)")
            lastErrorMessage = AccountErrorMessage.message(for: error)
        }
    }
}

