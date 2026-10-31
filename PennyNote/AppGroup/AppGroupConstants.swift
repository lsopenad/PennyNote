import Foundation

enum AppGroupConstants {
    // El grupo con el que se compila. AltStore vuelve a firmar la app con el equipo de quien la
    // instala y le cambia el identificador y el grupo (p. ej. "group.com.pennynote.app.ABCDE12345"),
    // así que el grupo real se averigua al arrancar.
    static let baseIdentifier = "group.com.pennynote.app"
    private static let baseBundleIdentifier = "com.pennynote.app"
    private static let widgetBundleSuffix = "widget"

    static let identifier = resolveIdentifier(
        infoDictionary: Bundle.main.infoDictionary ?? [:],
        bundleIdentifier: Bundle.main.bundleIdentifier
    )

    // Falso si la firma no incluye el grupo: SwiftData aborta la app si se le pide un grupo ajeno.
    static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static func resolveIdentifier(infoDictionary: [String: Any], bundleIdentifier: String?) -> String {
        // AltStore apunta en el Info.plist los grupos con los que ha firmado la app.
        if let groups = infoDictionary["ALTAppGroups"] as? [String],
           let group = groups.first(where: { $0.hasPrefix(baseIdentifier) }) ?? groups.first {
            return group
        }
        // Si no, el sufijo que AltStore añade al identificador ("com.pennynote.app.ABCDE12345", o
        // "com.pennynote.app.ABCDE12345.widget" en el widget) es el mismo que añade al grupo.
        guard let bundleIdentifier, bundleIdentifier.hasPrefix(baseBundleIdentifier + ".") else {
            return baseIdentifier
        }
        var components = bundleIdentifier.dropFirst(baseBundleIdentifier.count + 1).split(separator: ".")
        if components.last == Substring(widgetBundleSuffix) {
            components.removeLast()
        }
        return components.isEmpty ? baseIdentifier : ([baseIdentifier] + components.map(String.init)).joined(separator: ".")
    }

    enum Keys {
        static let widgetSnapshot = "widget.snapshot"
        static let currency = "settings.currency"
    }
}
