import Foundation
import SwiftData
import os

extension ModelContext {
    // Para lecturas cuyo fallo no debe cortar el flujo: se registra el error y se sigue sin resultados.
    // failureMessage se registra como público: no debe incluir datos del usuario.
    func fetchOrEmpty<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, failureMessage: String) -> [T] {
        do {
            return try fetch(descriptor)
        } catch {
            Log.data.error("\(failureMessage, privacy: .public): \(error.localizedDescription)")
            return []
        }
    }

    // Todas las categorías, por sortOrder: el orden en que se muestran.
    func categories(failureMessage: String) -> [ExpenseCategory] {
        fetchOrEmpty(FetchDescriptor<ExpenseCategory>(sortBy: [SortDescriptor(\.sortOrder)]), failureMessage: failureMessage)
    }

    func category(withID id: UUID, failureMessage: String) -> ExpenseCategory? {
        var descriptor = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return fetchOrEmpty(descriptor, failureMessage: failureMessage).first
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
