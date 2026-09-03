import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var newCategoryName = ""
    @State private var errorMessage: String?
    @State private var pendingDeleteOffsets: IndexSet?
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    Label(category.name, systemImage: category.symbolName)
                }
                .onDelete { offsets in
                    pendingDeleteOffsets = offsets
                    isDeleteConfirmationPresented = true
                }
            }

            Section {
                HStack {
                    TextField("Nueva categoría", text: $newCategoryName)
                    Button("Añadir", action: addCategory)
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
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

    private func confirmPendingDeletion() {
        guard let pendingDeleteOffsets else { return }
        delete(at: pendingDeleteOffsets)
        self.pendingDeleteOffsets = nil
    }

    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        ExpenseRepository.addCategory(name: trimmed, symbolName: "tag.fill", context: modelContext)
        newCategoryName = ""
        errorMessage = nil
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let didDelete = ExpenseRepository.deleteCategory(categories[index], context: modelContext)
            if !didDelete {
                errorMessage = "Debe quedar al menos una categoría."
                return
            }
        }
        errorMessage = nil
    }
}
