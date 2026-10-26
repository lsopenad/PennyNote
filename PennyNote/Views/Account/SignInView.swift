import SwiftUI

struct SignInView: View {
    @Environment(AccountSession.self) private var session

    @State private var email = ""
    @State private var password = ""
    @State private var operation = AccountOperation()

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !operation.isWorking
    }

    var body: some View {
        Form {
            Section {
                AuthHeader(subtitle: "Inicia sesión para guardar tus gastos en tu cuenta.")
            }
            .listRowBackground(Color.clear)

            Section {
                EmailField(email: $email)
                SecureField("Contraseña", text: $password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .onSubmit(signIn)
            }

            AuthErrorSection(message: operation.errorMessage)

            Section {
                AuthSubmitButton(title: "Iniciar sesión", isWorking: operation.isWorking, action: signIn)
                    .disabled(!canSubmit)
            }

            Section {
                NavigationLink("Crear una cuenta") {
                    SignUpView(initialEmail: email)
                }
            } footer: {
                Text("¿Has olvidado la contraseña? Pide una temporal a quien administra PennyNote y cámbiala después en Ajustes.")
            }

            Section {
                Button("Demo", action: session.enterDemo)
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
        // La cabecera ya lleva el nombre de la app; el título solo se usa en el botón de volver.
        .navigationTitle("Iniciar sesión")
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private func signIn() {
        guard canSubmit else { return }
        operation.run { [session, email, password] in
            try await session.signIn(email: email, password: password)
        }
    }
}

#Preview {
    NavigationStack {
        SignInView()
    }
    .environment(AccountSession(client: nil))
}
