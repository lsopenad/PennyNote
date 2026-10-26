import SwiftUI
import SwiftData

struct CategoryColorPickerView: View {
    @Environment(\.modelContext) private var modelContext
    let category: ExpenseCategory

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 16)]

    var body: some View {
        List {
            Section {
                Label(category.name, systemImage: category.symbolName)
                    .foregroundStyle(category.displayColor)
            }

            Section("Color") {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(CategoryColor.allCases) { color in
                        swatch(for: color)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func swatch(for color: CategoryColor) -> some View {
        let isSelected = category.color == color
        return Button {
            ExpenseRepository.setColor(color, for: category, context: modelContext)
        } label: {
            Circle()
                .fill(color.color)
                .frame(width: 44, height: 44)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.body.bold())
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
