import SwiftUI

// Lista de monedas con la elegida marcada, para la pantalla inicial y para Ajustes.
struct CurrencyPicker: View {
    @Binding var selection: AppCurrency

    var body: some View {
        Picker("Moneda", selection: $selection) {
            ForEach(AppCurrency.allCases) { currency in
                LabeledContent(currency.localizedName, value: currency.symbol)
                    .tag(currency)
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }
}
