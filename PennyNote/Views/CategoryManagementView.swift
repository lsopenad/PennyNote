import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    // La ficha abierta: una categoría nueva o la que se edita.
    @State private var form: FormTarget?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    Button {
                        form = .edit(category)
                    } label: {
                        Label {
                            Text(category.name)
                        } icon: {
                            CategoryIconImage(icon: category.icon)
                                .accessibilityHidden(true)
                        }
                    }
                    .foregroundStyle(.primary)
                    .swipeToDelete(
                        name: category.name,
                        message: "Los gastos de esta categoría pasarán a la categoría por defecto."
                    ) {
                        delete(category)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nueva categoría", systemImage: "plus") {
                    form = .new
                }
            }
        }
        .sheet(item: $form) { target in
            CategoryFormView(category: target.category)
        }
    }

    private func delete(_ category: ExpenseCategory) {
        let didDelete = ExpenseRepository.deleteCategory(category, context: modelContext)
        errorMessage = didDelete ? nil : String(localized: "Debe quedar al menos una categoría.")
    }

    private enum FormTarget: Identifiable {
        case new
        case edit(ExpenseCategory)

        var id: PersistentIdentifier? {
            category?.persistentModelID
        }

        var category: ExpenseCategory? {
            switch self {
            case .new: nil
            case .edit(let category): category
            }
        }
    }
}
