import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isReadOnly) private var isReadOnly
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var newCategoryName = ""
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    if isReadOnly {
                        categoryLabel(category)
                    } else {
                        NavigationLink {
                            CategoryColorPickerView(category: category)
                        } label: {
                            categoryLabel(category)
                        }
                        .swipeToDelete(
                            name: category.name,
                            message: "Los gastos de esta categoría pasarán a la categoría por defecto."
                        ) {
                            delete(category)
                        }
                    }
                }
            }

            if !isReadOnly {
                Section {
                    HStack {
                        TextField("Nueva categoría", text: $newCategoryName)
                        Button("Añadir", action: addCategory)
                            .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Categorías")
    }

    private func categoryLabel(_ category: ExpenseCategory) -> some View {
        Label {
            Text(category.name)
        } icon: {
            Image(systemName: category.symbolName)
                .foregroundStyle(category.displayColor)
        }
    }

    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        ExpenseRepository.addCategory(name: trimmed, symbolName: ExpenseCategory.defaultSymbolName, context: modelContext)
        newCategoryName = ""
        errorMessage = nil
    }

    private func delete(_ category: ExpenseCategory) {
        let didDelete = ExpenseRepository.deleteCategory(category, context: modelContext)
        errorMessage = didDelete ? nil : String(localized: "Debe quedar al menos una categoría.")
    }
}
