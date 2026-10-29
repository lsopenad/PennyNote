import Foundation

enum AppGroupConstants {
    static let identifier = "group.com.pennynote.app"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    enum Keys {
        static let widgetSnapshot = "widget.snapshot"
        static let currency = "settings.currency"
    }
}
