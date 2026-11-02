import SwiftUI
import SwiftData

struct CategoryPickerView: View {
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @Binding var selection: ExpenseCategory?
    var isSuggested = false

    var body: some View {
        Picker(selection: $selection) {
            Text(ExpenseCategory.uncategorizedLabel).tag(ExpenseCategory?.none)
            ForEach(categories) { category in
                CategoryMenuLabel(name: category.name, icon: category.icon)
                    .tag(ExpenseCategory?.some(category))
            }
        } label: {
            SuggestedFieldLabel(title: "Categoría", isSuggested: isSuggested)
        }
    }
}
