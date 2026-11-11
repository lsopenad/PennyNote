import Testing
@testable import PennyNote

struct AccountErrorMessageTests {
    @Test func wrongCurrentPasswordHasItsOwnMessage() {
        #expect(AccountErrorMessage.message(for: AccountError.wrongCurrentPassword) == String(localized: "La contraseña actual no es correcta."))
    }

    @Test func signedOutAsksToSignInAgain() {
        #expect(AccountErrorMessage.message(for: AccountError.signedOut) == String(localized: "La sesión ha caducado. Vuelve a iniciar sesión."))
    }
}
