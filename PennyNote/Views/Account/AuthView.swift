import SwiftUI

// Lo que se ve sin sesión: iniciar sesión, con enlace a crear cuenta.
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
