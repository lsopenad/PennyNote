import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isReadOnly) private var isReadOnly
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var newCategoryName = ""
    @State private var errorMessage: String?
    @State private var pendingDeleteOffsets: IndexSet?
    @State private var isDeleteConfirmationPresented = false

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
                    }
                }
                .onDelete(perform: isReadOnly ? nil : { offsets in
                    pendingDeleteOffsets = offsets
                    isDeleteConfirmationPresented = true
                })
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
        .confirmationDialog(
            "¿Eliminar categoría?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { confirmPendingDeletion() }
            Button("Cancelar", role: .cancel) { pendingDeleteOffsets = nil }
        } message: {
            Text("Los gastos de esta categoría pasarán a la categoría por defecto.")
        }
    }

    private func categoryLabel(_ category: ExpenseCategory) -> some View {
        Label {
            Text(category.name)
        } icon: {
            Image(systemName: category.symbolName)
                .foregroundStyle(category.displayColor)
        }
    }

    private func confirmPendingDeletion() {
        guard let pendingDeleteOffsets else { return }
        delete(at: pendingDeleteOffsets)
        self.pendingDeleteOffsets = nil
    }

    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        ExpenseRepository.addCategory(name: trimmed, symbolName: ExpenseCategory.defaultSymbolName, context: modelContext)
        newCategoryName = ""
        errorMessage = nil
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let didDelete = ExpenseRepository.deleteCategory(categories[index], context: modelContext)
            if !didDelete {
                errorMessage = String(localized: "Debe quedar al menos una categoría.")
                return
            }
        }
        errorMessage = nil
    }
}
