import SwiftUI

// Lo que se ve sin sesión: iniciar sesión, con enlaces a crear cuenta y recuperar la contraseña.
struct AuthView: View {
    var body: some View {
        NavigationStack {
            SignInView()
        }
    }
}

#Preview {
    AuthView()
        .environment(AccountSession(client: nil))
}
