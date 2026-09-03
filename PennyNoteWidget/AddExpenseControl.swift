import WidgetKit
import SwiftUI
import AppIntents

struct AddExpenseControl: ControlWidget {
    static let kind = "com.pennynote.app.AddExpenseControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenAddExpenseIntent()) {
                Label("Añadir gasto", systemImage: "plus.circle")
            }
        }
        .displayName("Añadir gasto")
        .description("Abre PennyNote para registrar un gasto nuevo.")
    }
}
