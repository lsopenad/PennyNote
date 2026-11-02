import SwiftUI

// Cuadrícula de los símbolos del catálogo, 5 por fila, cada uno en un círculo gris; el elegido lleva un
// anillo alrededor.
struct CategorySymbolGrid: View {
    @Binding var selection: CategoryIcon

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(CategorySymbolCatalog.symbols) { symbol in
                SymbolCell(symbol: symbol, isSelected: selection.symbolName == symbol.name) {
                    selection = CategoryIcon(symbolName: symbol.name)
                }
            }
        }
    }
}

private struct SymbolCell: View {
    let symbol: CategorySymbolCatalog.Symbol
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol.name)
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.tertiarySystemFill), in: Circle())
                .padding(5)
                .overlay {
                    Circle()
                        .strokeBorder(isSelected ? Color.secondary : Color.clear, lineWidth: 2.5)
                }
                .aspectRatio(1, contentMode: .fit)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(symbol.label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    CategorySymbolGrid(selection: .constant(.fallback))
        .padding()
}
