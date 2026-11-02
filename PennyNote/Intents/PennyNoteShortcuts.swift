import AppIntents

struct PennyNoteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Registra un gasto en \(.applicationName)",
                "Añade un gasto en \(.applicationName)",
            ],
            shortTitle: "Registrar gasto",
            systemImageName: "creditcard"
        )
        AppShortcut(
            intent: QuickExpenseIntent(),
            phrases: [
                "Gasto rápido en \(.applicationName)",
                "Apunta un gasto rápido en \(.applicationName)",
            ],
            shortTitle: "Gasto rápido",
            systemImageName: "bolt.circle"
        )
    }
}
