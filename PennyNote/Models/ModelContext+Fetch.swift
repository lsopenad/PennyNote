import Foundation
import SwiftData
import os

extension ModelContext {
    // Para lecturas cuyo fallo no debe cortar el flujo: se registra el error y se sigue sin resultados.
    func fetchOrEmpty<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, failureMessage: String) -> [T] {
        do {
            return try fetch(descriptor)
        } catch {
            Log.data.error("\(failureMessage, privacy: .public): \(error.localizedDescription)")
            return []
        }
    }

    // Guarda registrando el error en vez de propagarlo, para los puntos de escritura que no pueden fallar.
    func saveOrLog(failureMessage: String) {
        do {
            try save()
        } catch {
            Log.data.error("\(failureMessage, privacy: .public): \(error.localizedDescription)")
        }
    }
}
