import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var newCategoryName = ""
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    Label(category.name, systemImage: category.symbolName)
                }
                .onDelete(perform: delete)
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
