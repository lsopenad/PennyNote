import SwiftUI

// Selector del color de la categoría, 7 por fila: «Sin color», los de la paleta y uno personalizado con
// el ColorPicker del sistema. El elegido lleva un anillo alrededor, como en la cuadrícula de símbolos.
struct CategoryColorGrid: View {
    @Environment(\.self) private var environment
    @Binding var selection: CategoryColor?

    // Lo que muestra el ColorPicker: el personalizado guardado o, si no hay, el elegido de la paleta.
    @State private var customColor: Color

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    init(selection: Binding<CategoryColor?>) {
        _selection = selection
        _customColor = State(initialValue: selection.wrappedValue?.color ?? .gray)
    }

    private var isCustomSelected: Bool {
        if case .custom = selection { true } else { false }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ColorCell(isSelected: selection == nil, label: Text("Sin color")) {
                selection = nil
            } content: {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .overlay {
                        Image(systemName: "nosign")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
            }

            ForEach(CategoryPaletteColor.allCases) { paletteColor in
                ColorCell(isSelected: selection == .palette(paletteColor), label: Text(paletteColor.displayName)) {
                    selection = .palette(paletteColor)
                } content: {
                    Circle().fill(paletteColor.color)
                }
            }

            ColorPicker("Personalizado", selection: customColorSelection, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(1.25)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(5)
                .overlay {
                    Circle()
                        .strokeBorder(isCustomSelected ? Color.secondary : Color.clear, lineWidth: 2.5)
                }
                .aspectRatio(1, contentMode: .fit)
                .accessibilityAddTraits(isCustomSelected ? .isSelected : [])
        }
    }

    // Elegir en el ColorPicker selecciona siempre el personalizado, también si es el mismo color que ya
    // tenía: con onChange no se notaría al volver a él después de pasar por la paleta.
    private var customColorSelection: Binding<Color> {
        Binding {
            customColor
        } set: { newValue in
            customColor = newValue
            selection = CategoryColor(resolved: newValue.resolve(in: environment))
        }
    }
}

private struct ColorCell<Content: View>: View {
    let isSelected: Bool
    let label: Text
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            content
                .padding(5)
                .overlay {
                    Circle()
                        .strokeBorder(isSelected ? Color.secondary : Color.clear, lineWidth: 2.5)
                }
                .aspectRatio(1, contentMode: .fit)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    CategoryColorGrid(selection: .constant(.palette(.teal)))
        .padding()
}
