import Foundation
import Observation
import WidgetKit

// Moneda de la cuenta. Se guarda en el App Group, porque la lee el widget, y se sincroniza con
// public.user_settings con last-write-wins, como los gastos. Recibe el UserDefaults para poder usar
// uno aislado en los tests.
@MainActor
@Observable
final class CurrencySettings {
    // Una instalación de la 1.0.x con datos (ownerUserID guardado) veía euros: los sigue viendo hasta
    // que la primera sincronización traiga la moneda de la cuenta o pida elegirla.
    static let shared = CurrencySettings(
        defaults: AppGroupConstants.sharedDefaults,
        fallback: SyncStateStore.standard.ownerUserID == nil ? .regionDefault() : .eur
    )

    private(set) var currency: AppCurrency
    // La cuenta aún no tiene moneda en el servidor y hay que preguntarla. Solo se sabe tras bajar los
    // datos con conexión: sin ella no se pregunta, para no pisar una moneda elegida en otro móvil.
    private(set) var needsChoice = false

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let currency = AppGroupConstants.Keys.currency
        static let updatedAt = "settings.currencyUpdatedAt"
        static let isPending = "settings.currencyIsPending"
        static let all = [currency, updatedAt, isPending]
    }

    init(defaults: UserDefaults, fallback: AppCurrency = .regionDefault()) {
        self.defaults = defaults
        if let stored = AppCurrency.stored(in: defaults) {
            currency = stored
        } else {
            currency = fallback
            if fallback != .regionDefault() {
                // Guardada para que el widget muestre la misma.
                defaults.set(fallback.rawValue, forKey: Keys.currency)
            }
        }
    }

    // Elegida por el usuario: queda pendiente de subir. Quien la llama pide después la sincronización.
    func choose(_ currency: AppCurrency) {
        store(currency, updatedAt: .now, isPending: true)
        needsChoice = false
    }

    // MARK: - Sincronización

    var isPending: Bool {
        defaults.bool(forKey: Keys.isPending)
    }

    // La fila que hay que subir, si la moneda se ha cambiado aquí y aún no está en el servidor.
    var pendingRow: RemoteUserSettings? {
        guard isPending, let updatedAt = defaults.object(forKey: Keys.updatedAt) as? Date else { return nil }
        return RemoteUserSettings(currency: currency.rawValue, updatedAt: updatedAt)
    }

    // Aplica la fila bajada del servidor (nil si la cuenta no tiene). Sin fila y sin elección pendiente
    // se pide elegir, con `suggestion` preseleccionada.
    func apply(remote: RemoteUserSettings?, suggestion: () -> AppCurrency) {
        guard let remote else {
            // Ya preguntada: no se cambia la moneda por debajo de la hoja abierta.
            guard !isPending, !needsChoice else { return }
            store(suggestion(), updatedAt: nil, isPending: false)
            needsChoice = true
            return
        }
        needsChoice = false
        let localUpdatedAt = defaults.object(forKey: Keys.updatedAt) as? Date
        if isPending, let localUpdatedAt, SyncEngine.localWins(.pending, localUpdatedAt, over: remote.updatedAt) {
            return
        }
        guard let remoteCurrency = AppCurrency(rawValue: remote.currency) else {
            Log.sync.error("Moneda desconocida en el servidor: \(remote.currency)")
            return
        }
        store(remoteCurrency, updatedAt: remote.updatedAt, isPending: false)
    }

    // Tras subir `row`. Si la moneda ha vuelto a cambiar mientras se subía, sigue pendiente.
    func markSynced(_ row: RemoteUserSettings) {
        guard isPending, defaults.object(forKey: Keys.updatedAt) as? Date == row.updatedAt else { return }
        defaults.set(false, forKey: Keys.isPending)
    }

    // Al cerrar sesión o borrar la cuenta: la moneda es de la cuenta y se va con sus datos.
    func reset() {
        Keys.all.forEach(defaults.removeObject(forKey:))
        needsChoice = false
        setCurrency(.regionDefault())
    }

    // MARK: - Privado

    private func store(_ currency: AppCurrency, updatedAt: Date?, isPending: Bool) {
        defaults.set(currency.rawValue, forKey: Keys.currency)
        defaults.set(updatedAt, forKey: Keys.updatedAt)
        defaults.set(isPending, forKey: Keys.isPending)
        setCurrency(currency)
    }

    private func setCurrency(_ newValue: AppCurrency) {
        guard newValue != currency else { return }
        currency = newValue
        WidgetCenter.shared.reloadAllTimelines()
    }
}
