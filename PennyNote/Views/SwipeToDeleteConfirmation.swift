import SwiftUI

// Borrar deslizando una fila, con confirmación. El diálogo cuelga de la propia fila: desde iOS 26 sale
// como un globo que apunta a la vista que lo presenta, y puesto en la lista entera aparecía arriba
// del todo, sin que se viera qué se iba a borrar.
private struct SwipeToDeleteConfirmation: ViewModifier {
    let name: String
    let message: LocalizedStringKey?
    let onDelete: () -> Void

    @State private var isConfirmationPresented = false

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing) {
                // Sin role .destructive: con él la lista quita la fila antes de confirmar.
                Button("Eliminar", systemImage: "trash") { isConfirmationPresented = true }
                    .tint(.red)
            }
            .confirmationDialog(
                Text("¿Eliminar «\(name)»?", comment: "Confirmación al borrar deslizando; el nombre es el gasto, la categoría o el gasto recurrente"),
                isPresented: $isConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Eliminar", role: .destructive, action: onDelete)
                Button("Cancelar", role: .cancel) {}
            } message: {
                if let message {
                    Text(message)
                }
            }
    }
}

extension View {
    func swipeToDelete(name: String, message: LocalizedStringKey? = nil, onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDeleteConfirmation(name: name, message: message, onDelete: onDelete))
    }
}
