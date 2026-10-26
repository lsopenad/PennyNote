import Foundation

@MainActor
final class SyncTrigger {
    static let shared = SyncTrigger()

    // Agrupa ráfagas de cambios (varios gastos seguidos) en un único sync.
    private static let debounceInterval: Duration = .seconds(2.5)

    private var debounceTask: Task<Void, Never>?

    private init() {}

    func scheduleDebouncedSync() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }
            await SyncEngine.shared.syncNow()
        }
    }

    func syncNow() {
        Task { await SyncEngine.shared.syncNow() }
    }
}
