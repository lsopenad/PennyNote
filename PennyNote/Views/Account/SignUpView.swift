import SwiftUI

struct SignUpView: View {
    @Environment(AccountSession.self) private var session

    @State private var email: String
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var operation = AccountOperation()

    init(initialEmail: String = "") {
        _email = State(initialValue: initialEmail)
    }

    private var validationMessage: String? {
        if !password.isEmpty && !PasswordRules.isValid(password) {
            return "La contraseña debe tener al menos \(PasswordRules.minimumLength) caracteres."
        }
        if !passwordConfirmation.isEmpty && password != passwordConfirmation {
            return "Las contraseñas no coinciden."
        }
        return nil
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && PasswordRules.isValid(password)
            && password == passwordConfirmation
            && !operation.isWorking
    }

    var body: some View {
        Form {
            Section {
                EmailField(email: $email)
                SecureField("Contraseña", text: $password)
                    .textContentType(.newPassword)
                SecureField("Repite la contraseña", text: $passwordConfirmation)
                    .textContentType(.newPassword)
                    .submitLabel(.go)
                    .onSubmit(signUp)
            } footer: {
                Text(validationMessage ?? "Al menos \(PasswordRules.minimumLength) caracteres.")
                    .foregroundStyle(validationMessage == nil ? Color.secondary : Color.red)
            }

            AuthErrorSection(message: operation.errorMessage)

            Section {
                AuthSubmitButton(title: "Crear cuenta", isWorking: operation.isWorking, action: signUp)
                    .disabled(!canSubmit)
            }
        }
        .navigationTitle("Crear cuenta")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func signUp() {
        guard canSubmit else { return }
        operation.run { [session, email, password] in
            try await session.signUp(email: email, password: password)
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
    .environment(AccountSession(client: nil))
}
