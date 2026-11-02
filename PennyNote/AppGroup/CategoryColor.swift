import SwiftUI

// Color opcional de una categoría: uno de la paleta o uno personalizado. Se guarda como texto, en
// ExpenseCategory y en la columna color del servidor: el rawValue de la paleta («red») o «#RRGGBB».
// Compartido con el widget, que no conoce SwiftData.
enum CategoryColor: Hashable {
    case palette(CategoryPaletteColor)
    // sRGB, 0xRRGGBB.
    case custom(rgb: Int)

    // nil si no hay nada guardado o no se reconoce (de una versión futura, por ejemplo): la categoría se
    // muestra sin color.
    init?(storedValue: String?) {
        guard let storedValue else { return nil }
        if let paletteColor = CategoryPaletteColor(rawValue: storedValue) {
            self = .palette(paletteColor)
        } else if storedValue.count == 7, storedValue.first == "#",
                  storedValue.dropFirst().allSatisfy(\.isHexDigit),
                  let rgb = Int(storedValue.dropFirst(), radix: 16) {
            self = .custom(rgb: rgb)
        } else {
            return nil
        }
    }

    // El color elegido en el ColorPicker, ya resuelto. Los componentes fuera de sRGB (Display P3) se
    // recortan.
    init(resolved: Color.Resolved) {
        func byte(_ component: Float) -> Int {
            Int((min(max(component, 0), 1) * 255).rounded())
        }
        self = .custom(rgb: byte(resolved.red) << 16 | byte(resolved.green) << 8 | byte(resolved.blue))
    }

    var storedValue: String {
        switch self {
        case .palette(let paletteColor): paletteColor.rawValue
        case .custom(let rgb): String(format: "#%06X", rgb)
        }
    }

    var color: Color {
        switch self {
        case .palette(let paletteColor):
            paletteColor.color
        case .custom(let rgb):
            Color(
                .sRGB,
                red: Double((rgb >> 16) & 0xFF) / 255,
                green: Double((rgb >> 8) & 0xFF) / 255,
                blue: Double(rgb & 0xFF) / 255
            )
        }
    }

    // Color del símbolo sobre un círculo de este color: negro si el fondo es claro (amarillo o un
    // personalizado claro) y blanco en los demás. Los colores de la paleta cambian con el modo oscuro,
    // así que depende del entorno.
    func symbolColor(in environment: EnvironmentValues) -> Color {
        let resolved = color.resolve(in: environment)
        // Luminancia relativa (WCAG). El umbral es más alto que el de máximo contraste (0,18) para que,
        // como en los iconos del sistema, el verde, el naranja o el turquesa lleven el símbolo blanco.
        let luminance = 0.2126 * resolved.linearRed + 0.7152 * resolved.linearGreen + 0.0722 * resolved.linearBlue
        return luminance > 0.6 ? .black : .white
    }
}

// Paleta fija de colores de categoría, todos del sistema para que se adapten al modo oscuro. Se guarda
// por rawValue: no renombrar los casos.
enum CategoryPaletteColor: String, CaseIterable, Identifiable {
    case blue, orange, green, purple, pink, teal, yellow, red, indigo, mint, cyan, brown

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: .blue
        case .orange: .orange
        case .green: .green
        case .purple: .purple
        case .pink: .pink
        case .teal: .teal
        case .yellow: .yellow
        case .red: .red
        case .indigo: .indigo
        case .mint: .mint
        case .cyan: .cyan
        case .brown: .brown
        }
    }

    // Para VoiceOver en el selector de color.
    var displayName: LocalizedStringResource {
        switch self {
        case .blue: "Azul"
        case .orange: "Naranja"
        case .green: "Verde"
        case .purple: "Morado"
        case .pink: "Rosa"
        case .teal: "Turquesa"
        case .yellow: "Amarillo"
        case .red: "Rojo"
        case .indigo: "Índigo"
        case .mint: "Menta"
        case .cyan: "Cian"
        case .brown: "Marrón"
        }
    }
}
