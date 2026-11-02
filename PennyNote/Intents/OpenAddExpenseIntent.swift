import AppIntents
import Foundation

extension Notification.Name {
    static let pennyNoteOpenAddExpense = Notification.Name("com.pennynote.app.openAddExpense")
}

struct OpenAddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Añadir gasto"
    static var description = IntentDescription("Abre PennyNote en la pantalla de registrar gasto.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .pennyNoteOpenAddExpense, object: nil)
        return .result()
    }
}
