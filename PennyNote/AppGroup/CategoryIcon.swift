import SwiftUI

// Icono de una categoría: un símbolo SF del catálogo («fork.knife»). Se guarda como texto, en
// ExpenseCategory y en la columna icon del servidor. Compartido con el widget, que no conoce SwiftData.
struct CategoryIcon: Hashable {
    let symbolName: String

    // Con el que empieza una categoría nueva y el que sustituye a un icono guardado que no está en el
    // catálogo.
    static let fallback = CategoryIcon(symbolName: "tag.fill")
    // El de los gastos sin categoría. No está en el catálogo a propósito: ninguna categoría puede tenerlo.
    static let uncategorized = CategoryIcon(symbolName: "questionmark.circle")

    init(symbolName: String) {
        self.symbolName = symbolName
    }

    // Lo guardado puede ser un emoji de la 1.10.0 o un símbolo que ya no está en el catálogo: entonces
    // se usa fallback.
    init(storedValue: String) {
        self = CategorySymbolCatalog.contains(storedValue) ? CategoryIcon(symbolName: storedValue) : .fallback
    }

    var storedValue: String { symbolName }
}

// El icono suelto, en el color del texto. Toma el tamaño de la fuente del entorno.
struct CategoryIconImage: View {
    let icon: CategoryIcon

    var body: some View {
        Image(systemName: icon.symbolName)
            .foregroundStyle(.primary)
    }
}

// El icono sobre un círculo gris, como en las filas de gastos. Es decorativo: junto a él siempre va el
// nombre de la categoría.
struct CategoryIconBadge: View {
    let icon: CategoryIcon
    var diameter: CGFloat = 32
    var font: Font = .title3

    var body: some View {
        CategoryIconImage(icon: icon)
            .font(font)
            .frame(width: diameter, height: diameter)
            .background(Color(.tertiarySystemFill), in: Circle())
            .accessibilityHidden(true)
    }
}

// Nombre e icono para los menús (selector de categoría, filtros).
struct CategoryMenuLabel: View {
    let name: String
    let icon: CategoryIcon

    var body: some View {
        Label(name, systemImage: icon.symbolName)
    }
}
