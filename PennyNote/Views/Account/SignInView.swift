import SwiftUI
import SwiftData

struct SignInView: View {
    @Environment(AccountSession.self) private var session
    // Gastos de antes del login (versiones sin cuenta): se avisa de que se subirán.
    @Query(filter: #Predicate<Expense> { !$0.isSoftDeleted }) private var localExpenses: [Expense]

    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isWorking
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
            } footer: {
                if !localExpenses.isEmpty {
                    Text("Los gastos que ya tienes en este iPhone se guardarán en tu cuenta al entrar.")
                }
            }

            AuthErrorSection(message: errorMessage)

            Section {
                AuthSubmitButton(title: "Iniciar sesión", isWorking: isWorking, action: signIn)
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
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await session.signIn(email: email, password: password)
            } catch {
                errorMessage = AccountErrorMessage.message(for: error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignInView()
    }
    .environment(AccountSession(client: nil))
}
