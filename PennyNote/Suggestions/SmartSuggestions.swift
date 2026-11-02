import Foundation

// Ajuste de las sugerencias inteligentes del formulario de gasto. Se guarda en el UserDefaults de la
// app, sin sincronizar: es una preferencia de este iPhone.
enum SmartSuggestions {
    static let enabledKey = "smartSuggestionsEnabled"
    static let enabledByDefault = true
}
