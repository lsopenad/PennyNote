import SwiftUI

// Lista de monedas con búsqueda y la elegida marcada, para la pantalla inicial y para Ajustes. Arriba
// van las sugeridas (la que había al abrirla y la de la región) y debajo todas las que están en uso.
// Necesita una NavigationStack por encima para mostrar la barra de búsqueda.
struct CurrencyPicker: View {
    @Binding var selection: AppCurrency
    let footer: Text

    // Fijas mientras la lista está abierta: si siguieran a la selección, la fila tocada saltaría arriba.
    // En @State porque la vista se vuelve a crear con cada cambio de selección y solo vale la primera.
    // Incluye la moneda guardada aunque iOS ya no la tenga en la lista (una retirada).
    @State private var suggested: [Entry]
    @State private var query = ""

    init(selection: Binding<AppCurrency>, footer: Text) {
        _selection = selection
        self.footer = footer
        let initial = selection.wrappedValue
        let region = AppCurrency.regionDefault()
        _suggested = State(initialValue: (region == initial ? [initial] : [initial, region]).map(Entry.init(currency:)))
    }

    var body: some View {
        List {
            if query.isEmpty {
                Section {
                    rows(suggested)
                } header: {
                    Text("Sugeridas")
                } footer: {
                    footer
                }
                Section("Todas") {
                    rows(Self.all)
                }
            } else {
                rows(results)
            }
        }
        .searchable(text: $query, prompt: Text("Nombre, código o símbolo"))
        .overlay {
            if !query.isEmpty, results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    // Por nombre ("peso"), código ("MXN") o símbolo ("$"), sin distinguir mayúsculas ni tildes. También
    // entre las sugeridas que no están en la lista, como una moneda retirada que sigue elegida.
    private var results: [Entry] {
        let text = query.trimmingCharacters(in: .whitespaces)
        let candidates = suggested.filter { !Self.listed.contains($0.currency) } + Self.all
        guard !text.isEmpty else { return candidates }
        return candidates.filter {
            $0.name.localizedStandardContains(text) || $0.currency.rawValue.localizedStandardContains(text)
        }
    }

    private func rows(_ entries: [Entry]) -> some View {
        ForEach(entries) { entry in
            Button {
                selection = entry.currency
            } label: {
                HStack {
                    // Color.primary y no .primary: dentro de un botón, .primary es el tinte.
                    Text(entry.name)
                        .foregroundStyle(Color.primary)
                    Spacer()
                    if entry.currency == selection {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .fontWeight(.semibold)
                    }
                }
            }
            .accessibilityAddTraits(entry.currency == selection ? .isSelected : [])
        }
    }

    // El nombre se calcula una vez por moneda, no en cada pulsación de la búsqueda.
    private struct Entry: Identifiable {
        let currency: AppCurrency
        let name: String

        init(currency: AppCurrency) {
            self.currency = currency
            name = currency.displayName
        }

        var id: String { currency.id }
    }

    private static let all = AppCurrency.all.map(Entry.init(currency:))
    private static let listed = Set(AppCurrency.all)
}
