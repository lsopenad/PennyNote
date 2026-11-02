import AppIntents
import Testing
@testable import PennyNote

// Las acciones que guardan gastos sin abrir la app piden desbloquear el iPhone: con el móvil bloqueado
// nadie puede meter gastos en la cuenta ni ver sus categorías.
struct IntentAuthenticationTests {
    @Test func intentsThatSaveExpensesRequireUnlocking() {
        #expect(LogExpenseIntent.authenticationPolicy == .requiresAuthentication)
        #expect(QuickExpenseIntent.authenticationPolicy == .requiresAuthentication)
    }
}
