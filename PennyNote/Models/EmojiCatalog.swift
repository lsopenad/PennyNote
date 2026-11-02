import Foundation

// Grupos de emojis, en el orden de Unicode. El rawValue es el id que escribe
// scripts/generate-emoji-catalog.py en EmojiCatalog.json.
enum EmojiGroup: String, CaseIterable, Identifiable, Sendable {
    case smileys, people, nature, food, travel, activities, objects, symbols, flags

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .smileys: "Caras y emociones"
        case .people: "Personas"
        case .nature: "Animales y naturaleza"
        case .food: "Comida y bebida"
        case .travel: "Viajes y lugares"
        case .activities: "Actividades"
        case .objects: "Objetos"
        case .symbols: "Símbolos"
        case .flags: "Banderas"
        }
    }

    // Para la barra que salta a cada grupo, como en el teclado de emojis.
    var symbolName: String {
        switch self {
        case .smileys: "face.smiling"
        case .people: "person"
        case .nature: "leaf"
        case .food: "fork.knife"
        case .travel: "car"
        case .activities: "soccerball"
        case .objects: "lightbulb"
        case .symbols: "number"
        case .flags: "flag"
        }
    }
}

// Todos los emojis que se pueden elegir como icono de una categoría, con su nombre en el idioma de la
// app. Sale de EmojiCatalog.json, que genera scripts/generate-emoji-catalog.py a partir de los datos de
// Unicode y CLDR: iOS no publica la lista.
struct EmojiCatalog: Sendable {
    struct Emoji: Identifiable, Hashable, Sendable {
        let value: String
        // Para VoiceOver.
        let name: String
        // Nombre y palabras clave ya normalizados (ver normalized), para buscar.
        let searchText: String

        var id: String { value }
    }

    struct Group: Identifiable, Sendable {
        let kind: EmojiGroup
        let emojis: [Emoji]

        var id: EmojiGroup { kind }
    }

    let groups: [Group]

    // Se carga la primera vez que se pide; quien lo pida desde la interfaz, fuera del hilo principal.
    static let shared = EmojiCatalog(resource: "EmojiCatalog", language: appLanguage)

    // Los emojis cuyo nombre o palabras clave contienen todas las palabras buscadas, sin distinguir
    // mayúsculas ni acentos.
    func search(_ query: String) -> [Emoji] {
        let words = Self.normalized(query).split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return [] }
        return groups.flatMap(\.emojis).filter { emoji in
            words.allSatisfy { emoji.searchText.contains($0) }
        }
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    // El idioma en que se muestra la app (es, en o zh-Hans), que es una de las claves del catálogo.
    private static var appLanguage: String {
        Bundle.main.preferredLocalizations.first ?? fallbackLanguage
    }

    private static let fallbackLanguage = "en"

    init(groups: [Group]) {
        self.groups = groups
    }

    init(resource: String, language: String, bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            Log.data.error("Falta \(resource, privacy: .public).json en la app: el selector se queda sin emojis")
            self.init(groups: [])
            return
        }
        do {
            let file = try JSONDecoder().decode(CatalogFile.self, from: Data(contentsOf: url))
            self.init(groups: file.groups.compactMap { group in
                // Un grupo que esta versión no conoce no se muestra.
                guard let kind = EmojiGroup(rawValue: group.id) else { return nil }
                return Group(kind: kind, emojis: group.emojis.map { $0.emoji(language: language) })
            })
        } catch {
            Log.data.error("Fallo al leer el catálogo de emojis: \(error.localizedDescription)")
            self.init(groups: [])
        }
    }

    // Formato de EmojiCatalog.json: claves cortas porque son casi 2.000 emojis.
    private struct CatalogFile: Decodable {
        let groups: [GroupEntry]
    }

    private struct GroupEntry: Decodable {
        let id: String
        let emojis: [EmojiEntry]
    }

    private struct EmojiEntry: Decodable {
        // El emoji.
        let e: String
        // Nombre por idioma.
        let n: [String: String]
        // Palabras clave por idioma, separadas por espacios; puede faltar.
        let k: [String: String]?

        func emoji(language: String) -> Emoji {
            let name = n[language] ?? n[EmojiCatalog.fallbackLanguage] ?? e
            let keywords = k?[language] ?? k?[EmojiCatalog.fallbackLanguage] ?? ""
            return Emoji(value: e, name: name, searchText: EmojiCatalog.normalized("\(name) \(keywords)"))
        }
    }
}
