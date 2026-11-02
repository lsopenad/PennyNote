import Foundation

// Los símbolos SF que se pueden elegir como icono de una categoría, en el orden de la cuadrícula: 14
// filas de 5, por temas. Es una lista cerrada: un icono guardado que no esté aquí (un emoji de la 1.10.0
// o un símbolo retirado) se cambia por CategoryIcon.fallback. Todos existen en iOS 18, el mínimo de la
// app; lo comprueba CategoryIconTests.
enum CategorySymbolCatalog {
    struct Symbol: Identifiable {
        let name: String
        // Lo que lee VoiceOver en la cuadrícula.
        let label: LocalizedStringResource

        var id: String { name }
    }

    static let symbols: [Symbol] = [
        // Comida y bebida
        Symbol(name: "fork.knife", label: "Restaurante"),
        Symbol(name: "cup.and.saucer.fill", label: "Café"),
        Symbol(name: "mug.fill", label: "Taza"),
        Symbol(name: "wineglass.fill", label: "Copa de vino"),
        Symbol(name: "birthday.cake.fill", label: "Tarta"),
        Symbol(name: "takeoutbag.and.cup.and.straw.fill", label: "Comida para llevar"),
        Symbol(name: "carrot.fill", label: "Zanahoria"),
        Symbol(name: "cart.fill", label: "Carrito"),
        Symbol(name: "basket.fill", label: "Cesta"),
        // Compras
        Symbol(name: "bag.fill", label: "Bolsa"),
        Symbol(name: "tshirt.fill", label: "Camiseta"),
        Symbol(name: "shoe.fill", label: "Zapato"),
        Symbol(name: "gift.fill", label: "Regalo"),
        Symbol(name: "tag.fill", label: "Etiqueta"),
        Symbol(name: "scissors", label: "Tijeras"),
        // Transporte y viajes
        Symbol(name: "car.fill", label: "Coche"),
        Symbol(name: "bus.fill", label: "Autobús"),
        Symbol(name: "tram.fill", label: "Tranvía"),
        Symbol(name: "airplane", label: "Avión"),
        Symbol(name: "ferry.fill", label: "Barco"),
        Symbol(name: "bicycle", label: "Bicicleta"),
        Symbol(name: "scooter", label: "Patinete"),
        Symbol(name: "fuelpump.fill", label: "Gasolinera"),
        Symbol(name: "parkingsign.circle.fill", label: "Aparcamiento"),
        Symbol(name: "suitcase.fill", label: "Maleta"),
        Symbol(name: "beach.umbrella.fill", label: "Playa"),
        // Hogar
        Symbol(name: "house.fill", label: "Casa"),
        Symbol(name: "sofa.fill", label: "Sofá"),
        Symbol(name: "bed.double.fill", label: "Cama"),
        Symbol(name: "refrigerator.fill", label: "Nevera"),
        Symbol(name: "washer.fill", label: "Lavadora"),
        Symbol(name: "lightbulb.fill", label: "Bombilla"),
        Symbol(name: "powerplug.fill", label: "Enchufe"),
        Symbol(name: "drop.fill", label: "Agua"),
        Symbol(name: "flame.fill", label: "Gas"),
        Symbol(name: "wifi", label: "Wifi"),
        Symbol(name: "wrench.and.screwdriver.fill", label: "Herramientas"),
        Symbol(name: "key.fill", label: "Llave"),
        // Salud
        Symbol(name: "cross.case.fill", label: "Botiquín"),
        Symbol(name: "pills.fill", label: "Pastillas"),
        Symbol(name: "heart.fill", label: "Corazón"),
        Symbol(name: "stethoscope", label: "Estetoscopio"),
        Symbol(name: "dumbbell.fill", label: "Pesa"),
        Symbol(name: "figure.run", label: "Correr"),
        // Ocio
        Symbol(name: "gamecontroller.fill", label: "Mando de videojuegos"),
        Symbol(name: "film.fill", label: "Película"),
        Symbol(name: "tv.fill", label: "Televisión"),
        Symbol(name: "music.note", label: "Música"),
        Symbol(name: "ticket.fill", label: "Entrada"),
        Symbol(name: "theatermasks.fill", label: "Teatro"),
        Symbol(name: "book.fill", label: "Libro"),
        Symbol(name: "camera.fill", label: "Cámara"),
        Symbol(name: "soccerball", label: "Balón"),
        Symbol(name: "party.popper.fill", label: "Fiesta"),
        // Personas
        Symbol(name: "person.fill", label: "Persona"),
        Symbol(name: "person.2.fill", label: "Pareja"),
        Symbol(name: "figure.and.child.holdinghands", label: "Familia"),
        Symbol(name: "pawprint.fill", label: "Mascota"),
        Symbol(name: "graduationcap.fill", label: "Estudios"),
        Symbol(name: "briefcase.fill", label: "Trabajo"),
        // Dinero
        Symbol(name: "banknote.fill", label: "Billete"),
        Symbol(name: "creditcard.fill", label: "Tarjeta"),
        Symbol(name: "building.columns.fill", label: "Banco"),
        Symbol(name: "chart.line.uptrend.xyaxis", label: "Inversión"),
        Symbol(name: "doc.text.fill", label: "Documento"),
        Symbol(name: "shield.fill", label: "Seguro"),
        // Otros
        Symbol(name: "iphone", label: "Móvil"),
        Symbol(name: "laptopcomputer", label: "Ordenador"),
        Symbol(name: "star.fill", label: "Estrella"),
        Symbol(name: "ellipsis.circle.fill", label: "Otros"),
    ]

    private static let names = Set(symbols.map(\.name))

    static func contains(_ symbolName: String) -> Bool {
        names.contains(symbolName)
    }
}
