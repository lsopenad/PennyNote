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
    }
}
