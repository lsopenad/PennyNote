import Foundation

enum SyncStateStore {
    private static let defaults = UserDefaults.standard

    private enum Keys {
        static let notionDatabaseID = "sync.notionDatabaseID"
        static let lastSyncDate = "sync.lastSyncDate"
        static let lastSyncError = "sync.lastSyncError"
    }

    static var notionDatabaseID: String? {
        get { defaults.string(forKey: Keys.notionDatabaseID) }
        set { defaults.set(newValue, forKey: Keys.notionDatabaseID) }
    }

    static var lastSyncDate: Date? {
        get { defaults.object(forKey: Keys.lastSyncDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastSyncDate) }
    }

    static var lastSyncError: String? {
        get { defaults.string(forKey: Keys.lastSyncError) }
        set { defaults.set(newValue, forKey: Keys.lastSyncError) }
    }
}
