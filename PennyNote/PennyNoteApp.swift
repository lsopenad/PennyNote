import SwiftUI
import SwiftData

@main
struct PennyNoteApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer = SharedModelContainer.container
    @State private var session = AccountSession.shared
    @State private var sync = SyncCoordinator.shared
    @State private var currencySettings = CurrencySettings.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(sync)
                .environment(currencySettings)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Al abrir la app y al volver a ella, para que el widget no se quede con datos de un día anterior.
                WidgetSnapshotRefresher.refresh(in: modelContainer.mainContext)
                // Trae lo cambiado desde otros dispositivos y sube lo que haya quedado pendiente.
                sync.requestSync()
            }
        }
    }
}
