import SwiftUI

// Icono de una categoría: un símbolo SF («fork.knife») o un emoji («🍕»). Se guarda como texto, en
// ExpenseCategory y en la columna icon del servidor: los nombres de símbolo son ASCII y los emojis no,
// así que el texto basta para saber cuál es. Compartido con el widget, que no conoce SwiftData.
enum CategoryIcon: Hashable {
    case symbol(String)
    case emoji(String)

    init(storedValue: String) {
        self = storedValue.allSatisfy(\.isASCII) ? .symbol(storedValue) : .emoji(storedValue)
    }

    var storedValue: String {
        switch self {
        case .symbol(let value), .emoji(let value): value
        }
    }
}

// El icono suelto: el símbolo en el color de la app o el emoji con sus colores. Toma el tamaño de la
// fuente del entorno.
struct CategoryIconImage: View {
    let icon: CategoryIcon

    var body: some View {
        switch icon {
        case .symbol(let name):
            // Color.brand y no .tint: dentro del widget .tint es el azul del sistema.
            Image(systemName: name)
                .foregroundStyle(Color.brand)
        case .emoji(let emoji):
            Text(verbatim: emoji)
        }
    }
}

// El icono sobre un círculo del color de la app, como en las filas de gastos. Es decorativo: junto a
// él siempre va el nombre de la categoría.
struct CategoryIconBadge: View {
    let icon: CategoryIcon
    var diameter: CGFloat = 32
    var font: Font = .title3

    var body: some View {
        CategoryIconImage(icon: icon)
            .font(font)
            .frame(width: diameter, height: diameter)
            .background(Color.brand.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }
}

// Nombre e icono para los menús (selector de categoría, filtros): un menú solo dibuja iconos que sean
// imágenes, así que el emoji va delante del nombre.
struct CategoryMenuLabel: View {
    let name: String
    let icon: CategoryIcon

    var body: some View {
        switch icon {
        case .symbol(let symbolName):
            Label(name, systemImage: symbolName)
        case .emoji(let emoji):
            Text(verbatim: "\(emoji) \(name)")
        }
    }
}
