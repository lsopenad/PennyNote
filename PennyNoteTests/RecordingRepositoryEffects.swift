import Foundation
import SwiftData
import Testing
@testable import PennyNote

// Efectos de ExpenseRepository para los tests: cuentan las llamadas y guardan el estado de sync en un
// UserDefaults propio, sin tocar el widget, la sincronización ni el estado reales del simulador.
@MainActor
final class RecordingRepositoryEffects {
    private(set) var widgetRefreshCount = 0
    private(set) var syncRequestCount = 0
    let syncState: SyncStateStore

    init() throws {
        syncState = SyncStateStore(defaults: try #require(UserDefaults(suiteName: "ExpenseRepositoryTests.\(UUID())")))
    }

    // Para simular un guardado que falla.
    var failsToSave = false

    struct SaveFailure: Error {}

    var effects: ExpenseRepositoryEffects {
        ExpenseRepositoryEffects(
            refreshWidget: { [unowned self] _ in widgetRefreshCount += 1 },
            requestSync: { [unowned self] in syncRequestCount += 1 },
            syncState: syncState,
            save: { [unowned self] context in
                if failsToSave { throw SaveFailure() }
                try context.save()
            }
        )
    }
}
