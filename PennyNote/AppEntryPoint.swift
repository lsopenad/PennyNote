import SwiftUI

// Punto de entrada. Bajo los tests de unidad la app solo hace de anfitriona: no abre el almacén del App
// Group, no restaura la sesión ni sincroniza, para que los tests no toquen los datos, la cuenta ni el
// widget del simulador.
@main
enum AppEntryPoint {
    @MainActor
    static func main() {
        if isRunningUnitTests {
            UnitTestHostApp.main()
        } else {
            PennyNoteApp.main()
        }
    }

    // XCTest (y Swift Testing, que corre sobre él) pone esta variable en el proceso que aloja los tests.
    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

private struct UnitTestHostApp: App {
    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
    }
}
