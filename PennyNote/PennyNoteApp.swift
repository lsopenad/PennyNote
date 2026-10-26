import SwiftUI
import SwiftData

@main
struct PennyNoteApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer = SharedModelContainer.container

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Para que el widget no se quede con datos de otra versión de la app o de un día anterior.
                MonthlyTotalCalculator.refreshWidgetSnapshot(in: modelContainer.mainContext)
            }
        }
    }
}
