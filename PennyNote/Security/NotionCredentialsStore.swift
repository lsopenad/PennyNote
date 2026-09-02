import Foundation

// El token es una API key con acceso de lectura/escritura a Notion: solo Keychain, nunca UserDefaults.
enum NotionCredentialsStore {
    private static let service = "com.pennynote.notion"
    private static let account = "apiToken"

    static var token: String? {
        get { KeychainStore.get(service: service, account: account) }
        set {
            if let newValue, !newValue.isEmpty {
                KeychainStore.set(newValue, service: service, account: account)
            } else {
                KeychainStore.delete(service: service, account: account)
            }
        }
    }
}
