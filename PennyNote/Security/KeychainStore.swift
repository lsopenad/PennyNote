import Foundation
import Security
import os

enum KeychainStore {
    static func set(_ value: String, service: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            Log.security.error("Fallo al borrar el valor previo del Keychain (\(service)/\(account)): OSStatus \(deleteStatus)")
        }

        var newItem = query
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(newItem as CFDictionary, nil)
        if addStatus != errSecSuccess {
            Log.security.error("Fallo al guardar en el Keychain (\(service)/\(account)): OSStatus \(addStatus)")
        }
    }

    static func get(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess && status != errSecItemNotFound {
            Log.security.error("Fallo al leer del Keychain (\(service)/\(account)): OSStatus \(status)")
        }
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Log.security.error("Fallo al borrar del Keychain (\(service)/\(account)): OSStatus \(status)")
        }
    }
}
