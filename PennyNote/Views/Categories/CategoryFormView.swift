import SwiftUI
import SwiftData

// Ficha para crear una categoría o editar una existente: nombre e icono. Nada se guarda hasta pulsar
// Guardar; con cambios, cerrarla pide confirmación para descartarlos.
struct CategoryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [ExpenseCategory]

    // nil al crear una categoría nueva.
    private let category: ExpenseCategory?

    @State private var name: String
    @State private var icon: CategoryIcon
    @State private var isConfirmingDiscard = false

    @ScaledMetric(relativeTo: .largeTitle) private var previewDiameter: CGFloat = 88

    init(category: ExpenseCategory? = nil) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _icon = State(initialValue: category?.icon ?? ExpenseCategory.defaultIcon)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        guard let category else { return !trimmedName.isEmpty || icon != ExpenseCategory.defaultIcon }
        return trimmedName != category.name || icon != category.icon
    }

    private var isDuplicateName: Bool {
        let key = ExpenseCategory.nameKey(name)
        return categories.contains { $0 !== category && ExpenseCategory.nameKey($0.name) == key }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isDuplicateName
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CategoryIconBadge(icon: icon, diameter: previewDiameter, font: .system(size: previewDiameter * 0.45))
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Nombre", text: $name)
                        .onChange(of: name) { _, newValue in
                            // El servidor no admite nombres más largos.
                            if newValue.count > ExpenseLimits.categoryNameMaxLength {
                                name = ExpenseLimits.clampedCategoryName(newValue)
                            }
                        }
                    NavigationLink {
                        CategoryIconPicker(selection: $icon)
                    } label: {
                        LabeledContent("Icono") {
                            CategoryIconImage(icon: icon)
                                .accessibilityHidden(true)
                        }
                    }
                } footer: {
                    if isDuplicateName {
                        Text("Ya hay una categoría con este nombre.")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(category == nil ? Text("Nueva categoría") : Text("Editar categoría"))
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasChanges)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        if hasChanges {
                            isConfirmingDiscard = true
                        } else {
                            dismiss()
                        }
                    }
                    .confirmationDialog("¿Descartar los cambios?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                        Button("Descartar cambios", role: .destructive) { dismiss() }
                        Button("Seguir editando", role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        if let category {
            ExpenseRepository.updateCategory(category, name: trimmedName, icon: icon, context: modelContext)
        } else {
            ExpenseRepository.addCategory(name: trimmedName, icon: icon, context: modelContext)
        }
        dismiss()
    }
}

#Preview {
    CategoryFormView()
}
