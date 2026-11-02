import SwiftUI

// Etiqueta de un campo del formulario de gasto con un ✨ si su valor lo han rellenado las sugerencias.
struct SuggestedFieldLabel: View {
    let title: LocalizedStringKey
    let isSuggested: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            if isSuggested {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                    .accessibilityLabel(Text("Sugerido"))
                    .transition(.opacity)
            }
        }
    }
}
