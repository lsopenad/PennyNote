import SwiftUI

// Paleta fija de colores de categoría. Compartido con el widget, que pinta las categorías
// principales, así que no depende de SwiftData. Se guarda por rawValue: no renombrar los casos.
enum CategoryColor: String, CaseIterable, Identifiable {
    // Ordenados para que los colores consecutivos contrasten: es el orden en que se asignan.
    case blue, orange, green, purple, pink, teal, yellow, red, indigo, mint

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
        }
    }

    // Color de lo que no tiene categoría (o de una categoría cuyo color no se reconoce).
    static let neutral = Color.gray

    // Color a partir del rawValue guardado; gris si falta o no se reconoce.
    static func color(named rawValue: String?) -> Color {
        rawValue.flatMap(CategoryColor.init(rawValue:))?.color ?? neutral
    }

    // Primer color de la paleta que no esté en uso; si están todos, se reparte cíclicamente.
    static func nextAvailable(excluding used: [CategoryColor]) -> CategoryColor {
        allCases.first { !used.contains($0) } ?? allCases[used.count % allCases.count]
    }
}
