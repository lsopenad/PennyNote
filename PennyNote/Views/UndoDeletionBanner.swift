import SwiftUI

// Aviso de gasto eliminado con el botón Deshacer. Desaparece a los cinco segundos o al deslizarlo
// hacia abajo; mientras VoiceOver lo tiene enfocado no caduca, para dar tiempo a escucharlo.
struct UndoDeletionBanner: View {
    static let duration: Duration = .seconds(5)

    let deleted: DeletedExpense
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @AccessibilityFocusState private var isAccessibilityFocused: Bool

    private var message: String {
        String(localized: "«\(deleted.displayName)» eliminado", comment: "Aviso tras borrar un gasto deslizando; el nombre es el título del gasto o su categoría")
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Deshacer", action: onUndo)
                .fontWeight(.semibold)
                .foregroundStyle(.tint)
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .modifier(BannerBackground())
        // Un solo elemento para VoiceOver: lee el aviso y, al activarlo, deshace.
        .accessibilityElement(children: .combine)
        .accessibilityAction(.escape, onDismiss)
        .accessibilityFocused($isAccessibilityFocused)
        .gesture(
            DragGesture(minimumDistance: 10).onEnded { value in
                if value.translation.height > 20 { onDismiss() }
            }
        )
        // Por gasto y no al aparecer: si se borra otro con el aviso a la vista, la vista se reutiliza.
        .onChange(of: deleted.id, initial: true) {
            AccessibilityNotification.Announcement(message).post()
        }
        // Al cambiar de gasto o al perder el foco de VoiceOver, la cuenta empieza de nuevo.
        .task(id: TimerKey(deletedID: deleted.id, isAccessibilityFocused: isAccessibilityFocused)) {
            guard !isAccessibilityFocused else { return }
            do {
                try await Task.sleep(for: Self.duration)
                // La cancelación puede llegar con el sueño ya acabado: sin esto cerraría el aviso de otro gasto.
                guard !Task.isCancelled else { return }
                onDismiss()
            } catch {
                // Cancelado: se ha borrado otro gasto, se ha cerrado el aviso o VoiceOver lo ha enfocado.
            }
        }
    }

    private struct TimerKey: Equatable {
        let deletedID: UUID
        let isAccessibilityFocused: Bool
    }
}

// Liquid Glass desde iOS 26, como los avisos del sistema; material en las versiones anteriores.
private struct BannerBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.regularMaterial, in: .capsule)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        }
    }
}
