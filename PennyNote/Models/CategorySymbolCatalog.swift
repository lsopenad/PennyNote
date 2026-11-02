import Foundation

// Símbolos SF que se pueden elegir como icono de una categoría: una selección pensada para gastos (para
// todo lo demás están los emojis). Todos existen en iOS 18, el mínimo de la app; lo comprueba
// CategoryIconTests.
enum CategorySymbolCatalog {
    struct Group: Identifiable {
        let title: LocalizedStringResource
        let symbols: [String]

        var id: String { symbols[0] }
    }

    static let groups: [Group] = [
        Group(title: "Comida y bebida", symbols: [
            "fork.knife", "cup.and.saucer.fill", "mug.fill", "wineglass.fill", "birthday.cake.fill",
            "takeoutbag.and.cup.and.straw.fill", "carrot.fill", "fish.fill", "cart.fill", "basket.fill",
        ]),
        Group(title: "Transporte", symbols: [
            "car.fill", "bus.fill", "tram.fill", "train.side.front.car", "airplane", "bicycle", "scooter",
            "fuelpump.fill", "ev.charger.fill", "parkingsign.circle.fill", "sailboat.fill", "figure.walk",
        ]),
        Group(title: "Hogar", symbols: [
            "house.fill", "bed.double.fill", "sofa.fill", "lightbulb.fill", "bolt.fill", "drop.fill",
            "flame.fill", "wifi", "phone.fill", "washer.fill", "hammer.fill", "wrench.and.screwdriver.fill",
            "key.fill", "leaf.fill",
        ]),
        Group(title: "Salud", symbols: [
            "cross.case.fill", "pills.fill", "heart.fill", "stethoscope", "bandage.fill", "figure.run",
            "dumbbell.fill", "brain.head.profile", "eye.fill",
        ]),
        Group(title: "Ocio", symbols: [
            "gamecontroller.fill", "film.fill", "tv.fill", "music.note", "ticket.fill", "theatermasks.fill",
            "book.fill", "headphones", "camera.fill", "paintpalette.fill", "sportscourt.fill", "soccerball",
            "beach.umbrella.fill", "tent.fill", "party.popper.fill",
        ]),
        Group(title: "Compras", symbols: [
            "bag.fill", "creditcard.fill", "gift.fill", "tshirt.fill", "shoe.fill", "handbag.fill",
            "eyeglasses", "scissors", "sparkles",
        ]),
        Group(title: "Personas y mascotas", symbols: [
            "person.fill", "person.2.fill", "figure.and.child.holdinghands", "stroller.fill", "pawprint.fill",
            "dog.fill", "cat.fill", "graduationcap.fill", "backpack.fill", "briefcase.fill",
        ]),
        Group(title: "Dinero", symbols: [
            "banknote.fill", "dollarsign.circle.fill", "eurosign.circle.fill", "building.columns.fill",
            "chart.line.uptrend.xyaxis", "percent", "doc.text.fill", "envelope.fill", "shield.fill",
            "arrow.left.arrow.right",
        ]),
        Group(title: "Otros", symbols: [
            "tag.fill", "star.fill", "globe", "laptopcomputer", "iphone", "ellipsis.circle.fill",
        ]),
    ]
}
