import SwiftUI

// Lista de monedas con la elegida marcada, para la pantalla inicial y para Ajustes.
struct CurrencyPicker: View {
    @Binding var selection: AppCurrency

    var body: some View {
        Picker("Moneda", selection: $selection) {
            // Un solo Text: el Picker en línea solo muestra el valor de un LabeledContent, no su título.
            ForEach(AppCurrency.allCases) { currency in
                Text(currency.displayName)
                    .tag(currency)
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }
}
