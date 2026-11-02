import WidgetKit
import SwiftUI
import AppIntents

struct AddExpenseControl: ControlWidget {
    // Se conserva el kind de cuando abría la app: así quien ya lo tenía puesto no tiene que volver a añadirlo.
    static let kind = "com.pennynote.app.AddExpenseControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: QuickExpenseIntent()) {
                Label("Gasto rápido", systemImage: "plus.circle")
            }
        }
        .displayName("Gasto rápido")
        .description("Registra un gasto sin abrir PennyNote. Los detalles se completan luego.")
    }
}
