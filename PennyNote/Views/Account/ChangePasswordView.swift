import SwiftUI

// Cambio de contraseña con la sesión iniciada; también es el paso final cuando alguien entra con
// una contraseña temporal que le ha puesto quien administra la app.
struct ChangePasswordView: View {
    @Environment(AccountSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var operation = AccountOperation()
    @State private var isDonePresented = false

    private var canSubmit: Bool {
        PasswordRules.isValid(password) && password == passwordConfirmation && !operation.isWorking
    }

    var body: some View {
        Form {
            Section {
                // Para que el autorrelleno de contraseñas sepa a qué cuenta pertenece la nueva.
                TextField("Email", text: .constant(session.userEmail ?? ""))
                    .textContentType(.username)
                    .disabled(true)
                    .foregroundStyle(.secondary)
                SecureField("Contraseña nueva", text: $password)
                    .textContentType(.newPassword)
                SecureField("Repite la contraseña", text: $passwordConfirmation)
                    .textContentType(.newPassword)
                    .submitLabel(.done)
                    .onSubmit(changePassword)
            } footer: {
                if !passwordConfirmation.isEmpty && password != passwordConfirmation {
                    Text("Las contraseñas no coinciden.").foregroundStyle(.red)
                } else {
                    Text("Al menos \(PasswordRules.minimumLength) caracteres.")
                }
            }

            AuthErrorSection(message: operation.errorMessage)

            Section {
                AuthSubmitButton(title: "Cambiar contraseña", isWorking: operation.isWorking, action: changePassword)
                    .disabled(!canSubmit)
            }
        }
        .navigationTitle("Cambiar contraseña")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Contraseña cambiada", isPresented: $isDonePresented) {
            Button("Aceptar") { dismiss() }
        }
    }

    private func changePassword() {
        guard canSubmit else { return }
        operation.run { [session, password] in
            try await session.updatePassword(password)
            isDonePresented = true
        }
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
    }
    .environment(AccountSession(client: nil))
}
