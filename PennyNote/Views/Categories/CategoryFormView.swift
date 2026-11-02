import SwiftUI
import SwiftData

// Ficha para crear una categoría o editar una existente: vista previa del icono, nombre y la cuadrícula
// de símbolos. Nada se guarda hasta pulsar Guardar; con cambios, cerrarla pide confirmación para
// descartarlos.
struct CategoryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [ExpenseCategory]

    // nil al crear una categoría nueva.
    private let category: ExpenseCategory?

    @State private var name: String
    @State private var icon: CategoryIcon
    @State private var isConfirmingDiscard = false

    @ScaledMetric(relativeTo: .largeTitle) private var previewSize: CGFloat = 112

    init(category: ExpenseCategory? = nil) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _icon = State(initialValue: category?.icon ?? .fallback)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        guard let category else { return !trimmedName.isEmpty || icon != .fallback }
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
            ScrollView {
                VStack(spacing: 24) {
                    CategoryIconImage(icon: icon)
                        .font(.system(size: previewSize * 0.45))
                        .frame(width: previewSize, height: previewSize)
                        .background(
                            Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: previewSize * 0.25, style: .continuous)
                        )
                        .accessibilityHidden(true)

                    nameField

                    CategorySymbolGrid(selection: $icon)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(category == nil ? Text("Nueva categoría") : Text("Editar categoría"))
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasChanges)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    cancelButton
                        .confirmationDialog("¿Descartar los cambios?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                            Button("Descartar cambios", role: .destructive) { dismiss() }
                            Button("Seguir editando", role: .cancel) {}
                        }
                }
                ToolbarItem(placement: .confirmationAction) {
                    saveButton
                        .disabled(!canSave)
                }
            }
        }
    }

    private var nameField: some View {
        VStack(spacing: 8) {
            TextField("Nombre", text: $name)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
                .padding(.horizontal)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                .onChange(of: name) { _, newValue in
                    // El servidor no admite nombres más largos.
                    if newValue.count > ExpenseLimits.categoryNameMaxLength {
                        name = ExpenseLimits.clampedCategoryName(newValue)
                    }
                }

            if isDuplicateName {
                Text("Ya hay una categoría con este nombre.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    // En iOS 26 los papeles de los botones dibujan la X y la marca de la barra; antes, el texto.
    @ViewBuilder
    private var cancelButton: some View {
        if #available(iOS 26, *) {
            Button(role: .cancel, action: cancel)
        } else {
            Button("Cancelar", action: cancel)
        }
    }

    @ViewBuilder
    private var saveButton: some View {
        if #available(iOS 26, *) {
            Button(role: .confirm, action: save)
        } else {
            Button("Guardar", action: save)
        }
    }

    private func cancel() {
        if hasChanges {
            isConfirmingDiscard = true
        } else {
            dismiss()
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
