import Foundation

// Estado de la sincronización que no vive en SwiftData. Se guarda en UserDefaults de la app (no en el
// App Group): el widget no lo necesita. Recibe el UserDefaults para poder usar uno aislado en los tests.
final class SyncStateStore {
    static let standard = SyncStateStore(defaults: .standard)

    private let defaults: UserDefaults

    private enum Keys {
        static let ownerUserID = "sync.ownerUserID"
        static let categoriesCursor = "sync.categoriesCursor"
        static let expensesCursor = "sync.expensesCursor"
        static let categoryTombstones = "sync.categoryTombstones"
        static let lastSyncDate = "sync.lastSyncDate"
        static let needsCategoryMerge = "sync.needsCategoryMerge"
        static let all = [ownerUserID, categoriesCursor, expensesCursor, categoryTombstones, lastSyncDate, needsCategoryMerge]
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // Usuario al que pertenecen los datos locales; nil si son anteriores al login.
    var ownerUserID: UUID? {
        get { defaults.string(forKey: Keys.ownerUserID).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: Keys.ownerUserID) }
    }

    // Último server_updated_at recibido de cada tabla.
    var categoriesCursor: Date? {
        get { defaults.object(forKey: Keys.categoriesCursor) as? Date }
        set { defaults.set(newValue, forKey: Keys.categoriesCursor) }
    }

    var expensesCursor: Date? {
        get { defaults.object(forKey: Keys.expensesCursor) as? Date }
        set { defaults.set(newValue, forKey: Keys.expensesCursor) }
    }

    var lastSyncDate: Date? {
        get { defaults.object(forKey: Keys.lastSyncDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastSyncDate) }
    }

    // Tras subir por primera vez los datos de antes del login hay que juntar las categorías que se
    // llamen igual que otras que ya tuviera la cuenta (si se usó antes en otro móvil).
    var needsCategoryMerge: Bool {
        get { defaults.bool(forKey: Keys.needsCategoryMerge) }
        set { defaults.set(newValue, forKey: Keys.needsCategoryMerge) }
    }

    // Las categorías se borran de SwiftData en el acto; su borrado pendiente de subir se guarda aquí.
    var categoryTombstones: [RemoteCategory] {
        get {
            guard let data = defaults.data(forKey: Keys.categoryTombstones) else { return [] }
            do {
                return try JSONDecoder().decode([RemoteCategory].self, from: data)
            } catch {
                Log.sync.error("Fallo al leer las categorías borradas pendientes de subir: \(error.localizedDescription)")
                return []
            }
        }
        set {
            do {
                defaults.set(try JSONEncoder().encode(newValue), forKey: Keys.categoryTombstones)
            } catch {
                Log.sync.error("Fallo al guardar las categorías borradas pendientes de subir: \(error.localizedDescription)")
            }
        }
    }

    func addCategoryTombstone(_ tombstone: RemoteCategory) {
        categoryTombstones = categoryTombstones.filter { $0.id != tombstone.id } + [tombstone]
    }

    func reset() {
        Keys.all.forEach(defaults.removeObject(forKey:))
    }
}
