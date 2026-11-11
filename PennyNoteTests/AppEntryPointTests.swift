import Testing
@testable import PennyNote

struct AppEntryPointTests {
    // Si deja de detectarse, la app vuelve a arrancar de verdad (almacén, sesión y sincronización) al
    // pasar los tests.
    @Test func unitTestsAreDetected() {
        #expect(AppEntryPoint.isRunningUnitTests)
    }
}
