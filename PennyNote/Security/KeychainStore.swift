import Foundation
import Security
import os

enum KeychainStore {
    static func set(_ value: String, service: String, account: String) {
        let query = baseQuery(service: service, account: account)
        let deleteStatus = SecItemDelete(query as CFDictionary)
        logFailure(deleteStatus, action: "borrar el valor previo del", service: service, account: account)

        var newItem = query
        newItem[kSecValueData as String] = Data(value.utf8)
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(newItem as CFDictionary, nil)
        logFailure(addStatus, action: "guardar en el", service: service, account: account)
    }

    static func get(service: String, account: String) -> String? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        logFailure(status, action: "leer del", service: service, account: account)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, account: String) {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        logFailure(status, action: "borrar del", service: service, account: account)
    }

    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    // errSecItemNotFound no es un fallo: es el caso normal cuando todavía no hay valor guardado.
    private static func logFailure(_ status: OSStatus, action: String, service: String, account: String) {
        guard status != errSecSuccess, status != errSecItemNotFound else { return }
        Log.security.error("Fallo al \(action, privacy: .public) Keychain (\(service, privacy: .public)/\(account, privacy: .public)): OSStatus \(status)")
    }
}
