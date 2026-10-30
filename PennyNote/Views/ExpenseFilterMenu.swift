import SwiftUI
import SwiftData

struct ExpenseFilterMenu: View {
    @Binding var filter: ExpenseFilter
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    var body: some View {
        Menu {
            Section("Categoría") {
                ForEach(categories) { category in
                    Toggle(isOn: $filter.categoryIDs.containing(category.id)) {
                        Label(category.name, systemImage: category.symbolName)
                    }
                }
                Toggle(ExpenseCategory.uncategorizedLabel, isOn: $filter.includesUncategorized)
            }
            Section("Método de pago") {
                ForEach(PaymentMethod.allCases) { method in
                    Toggle(isOn: $filter.paymentMethods.containing(method)) {
                        Text(method.title)
                    }
                }
            }
            if filter.isActive {
                Divider()
                Button("Limpiar filtros", role: .destructive) { filter.clear() }
            }
        } label: {
            Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }
}

private extension Binding {
    // Toggle sobre la pertenencia de un elemento a un conjunto.
    func containing<Element: Hashable>(_ element: Element) -> Binding<Bool> where Value == Set<Element> {
        Binding<Bool>(
            get: { wrappedValue.contains(element) },
            set: { isOn in
                if isOn { wrappedValue.insert(element) } else { wrappedValue.remove(element) }
            }
        )
    }
}
