import SwiftUI
import SwiftData

struct CategoryPickerView: View {
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @Binding var selection: ExpenseCategory?

    var body: some View {
        Picker("Categoría", selection: $selection) {
            Text(ExpenseCategory.uncategorizedLabel).tag(ExpenseCategory?.none)
            ForEach(categories) { category in
                Label(category.name, systemImage: category.symbolName)
                    .tag(ExpenseCategory?.some(category))
            }
        }
    }
}
