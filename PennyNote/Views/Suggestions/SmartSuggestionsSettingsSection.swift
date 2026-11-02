import SwiftUI

// Ajustes → interruptor de las sugerencias inteligentes del formulario de gasto.
struct SmartSuggestionsSettingsSection: View {
    @AppStorage(SmartSuggestions.enabledKey) private var isEnabled = SmartSuggestions.enabledByDefault

    var body: some View {
        Section {
            Toggle("Sugerencias inteligentes", isOn: $isEnabled)
        } footer: {
            Text("Al escribir el título de un gasto nuevo o por completar, PennyNote te propone gastos anteriores parecidos para rellenar el importe, la categoría y el método de pago. Si no hay ninguno, sugiere la categoría y el método de pago según las palabras del título. Aprende de tus gastos de los últimos 12 meses.")
        }
    }
}
