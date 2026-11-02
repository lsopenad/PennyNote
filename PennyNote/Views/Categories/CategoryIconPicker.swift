import SwiftUI

// Selector del icono de una categoría: todos los emojis, con buscador y una barra para saltar de grupo,
// o una selección de símbolos SF. Al elegir uno vuelve a la ficha.
struct CategoryIconPicker: View {
    @Binding var selection: CategoryIcon

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode

    init(selection: Binding<CategoryIcon>) {
        _selection = selection
        _mode = State(initialValue: Mode(selection.wrappedValue))
    }

    var body: some View {
        Group {
            switch mode {
            case .emoji:
                EmojiGrid(selection: selection, onSelect: select)
            case .symbol:
                SymbolGrid(selection: selection, onSelect: select)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Tipo de icono", selection: $mode) {
                    Text("Emoji").tag(Mode.emoji)
                    Text("Símbolo").tag(Mode.symbol)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }

    private func select(_ icon: CategoryIcon) {
        selection = icon
        dismiss()
    }

    private enum Mode {
        case emoji, symbol

        init(_ icon: CategoryIcon) {
            switch icon {
            case .emoji: self = .emoji
            case .symbol: self = .symbol
            }
        }
    }
}

// Celda de la cuadrícula: el icono, con un círculo detrás si es el elegido.
private struct IconCell<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 44

    var body: some View {
        Button(action: action) {
            label
                .frame(width: size, height: size)
                .background {
                    if isSelected {
                        Circle().fill(Color.brand.opacity(0.2))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct EmojiGrid: View {
    let selection: CategoryIcon
    let onSelect: (CategoryIcon) -> Void

    // nil hasta que se carga, fuera del hilo principal.
    @State private var catalog: EmojiCatalog?
    @State private var query = ""

    @ScaledMetric(relativeTo: .title) private var cellSize: CGFloat = 44

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cellSize), spacing: 4)]
    }

    var body: some View {
        // nil sin búsqueda: entonces se muestran todos los grupos.
        let results = query.trimmingCharacters(in: .whitespaces).isEmpty ? nil : catalog?.search(query)
        ScrollViewReader { proxy in
            ScrollView {
                if let results {
                    searchResults(results)
                } else if let catalog {
                    allGroups(catalog)
                }
            }
            .overlay {
                if catalog == nil {
                    ProgressView()
                } else if let results, results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let catalog, results == nil {
                    groupBar(catalog, proxy: proxy)
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Buscar emoji"))
        .task {
            // Son casi 2.000 emojis con sus nombres: se leen fuera del hilo principal.
            catalog = await Task.detached(priority: .userInitiated) { EmojiCatalog.shared }.value
        }
    }

    private func allGroups(_ catalog: EmojiCatalog) -> some View {
        LazyVGrid(columns: columns, spacing: 4, pinnedViews: .sectionHeaders) {
            ForEach(catalog.groups) { group in
                Section {
                    ForEach(group.emojis) { cell(for: $0) }
                } header: {
                    Text(group.kind.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .background(.background)
                        .accessibilityAddTraits(.isHeader)
                        // En la cabecera y no en la sección: la barra de grupos salta a ella.
                        .id(group.kind)
                }
            }
        }
        .padding(.horizontal)
    }

    private func searchResults(_ emojis: [EmojiCatalog.Emoji]) -> some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(emojis) { cell(for: $0) }
        }
        .padding(.horizontal)
    }

    private func cell(for emoji: EmojiCatalog.Emoji) -> some View {
        IconCell(isSelected: selection == .emoji(emoji.value), action: { onSelect(.emoji(emoji.value)) }) {
            Text(verbatim: emoji.value)
                .font(.title)
        }
        .accessibilityLabel(Text(verbatim: emoji.name))
    }

    private func groupBar(_ catalog: EmojiCatalog, proxy: ScrollViewProxy) -> some View {
        HStack {
            ForEach(catalog.groups) { group in
                Button {
                    proxy.scrollTo(group.kind, anchor: .top)
                } label: {
                    Image(systemName: group.kind.symbolName)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityLabel(Text(group.kind.title))
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .background(.bar)
    }
}

private struct SymbolGrid: View {
    let selection: CategoryIcon
    let onSelect: (CategoryIcon) -> Void

    @ScaledMetric(relativeTo: .title) private var cellSize: CGFloat = 44

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: cellSize), spacing: 8)], spacing: 8) {
                ForEach(CategorySymbolCatalog.groups) { group in
                    Section {
                        ForEach(group.symbols, id: \.self) { symbolName in
                            IconCell(isSelected: selection == .symbol(symbolName), action: { onSelect(.symbol(symbolName)) }) {
                                Image(systemName: symbolName)
                                    .font(.title2)
                                    .foregroundStyle(Color.brand)
                            }
                        }
                    } header: {
                        Text(group.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 12)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    NavigationStack {
        CategoryIconPicker(selection: .constant(.emoji("🍕")))
    }
}
