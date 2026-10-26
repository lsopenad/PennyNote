import Foundation
import Security

// Borra lo que dejó en el dispositivo la sincronización con Notion, que ya no existe: el token
// de integración (una API key con acceso a Notion) no debe quedarse en el Keychain sin uso.
enum LegacyNotionCleanup {
    private static let doneKey = "legacy.notionCleanupDone"

    private static let keychainService = "com.pennynote.notion"
    private static let keychainAccount = "apiToken"

    private static let defaultsKeys = ["sync.notionDatabaseID", "sync.lastSyncDate", "sync.lastSyncError"]

    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        let status = SecItemDelete(query as CFDictionary)
        // errSecItemNotFound es lo normal si nunca se configuró Notion. Ante otro error no se marca
        // como hecho, para reintentarlo en el siguiente arranque.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            Log.security.error("Fallo al borrar el token de Notion del Keychain: OSStatus \(status)")
            return
        }

        defaultsKeys.forEach(defaults.removeObject(forKey:))
        defaults.set(true, forKey: doneKey)
    }
}
