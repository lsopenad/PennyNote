import Foundation

@MainActor
final class SyncTrigger {
    static let shared = SyncTrigger()

    private var debounceTask: Task<Void, Never>?

    private init() {}

    func scheduleDebouncedSync() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            await SyncEngine.shared.syncNow()
        }
    }

    func syncNow() {
        Task { await SyncEngine.shared.syncNow() }
    }
}
