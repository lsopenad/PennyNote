import Foundation

// Compartido con el widget. El esquema debe coincidir con CFBundleURLSchemes de project.yml.
enum DeepLinkURL {
    static let scheme = "pennynote"
    static let addExpenseHost = "add"
    static let addExpense = URL(string: "\(scheme)://\(addExpenseHost)")!
    static let statisticsHost = "stats"
    static let statistics = URL(string: "\(scheme)://\(statisticsHost)")!
}
