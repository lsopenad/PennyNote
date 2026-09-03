import WidgetKit
import SwiftUI

@main
struct PennyNoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        HomeScreenWidget()
        LockScreenWidget()
        AddExpenseControl()
    }
}
