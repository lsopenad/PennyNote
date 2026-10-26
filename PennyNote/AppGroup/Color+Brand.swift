import SwiftUI

extension Color {
    // Verde de la app pedido por nombre al catálogo, que se comparte con el widget en project.yml.
    // Dentro de un widget Color.accentColor no lo recoge y sale el azul del sistema.
    static let brand = Color("AccentColor")
}
