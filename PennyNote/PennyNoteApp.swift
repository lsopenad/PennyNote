import SwiftUI
import SwiftData

@main
struct PennyNoteApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer = SharedModelContainer.container
    @State private var session = AccountSession.shared
    @State private var sync = SyncCoordinator.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(sync)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Para que el widget no se quede con datos de otra versión de la app o de un día anterior.
                WidgetSnapshotRefresher.refresh(in: modelContainer.mainContext)
                // Trae lo cambiado desde otros dispositivos y sube lo que haya quedado pendiente.
                sync.requestSync()
            }
        }
    }
}
