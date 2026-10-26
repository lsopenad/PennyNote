import SwiftUI

struct SignUpView: View {
    @Environment(AccountSession.self) private var session

    @State private var email: String
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

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
            && !isWorking
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

            AuthErrorSection(message: errorMessage)

            Section {
                AuthSubmitButton(title: "Crear cuenta", isWorking: isWorking, action: signUp)
                    .disabled(!canSubmit)
            }
        }
        .navigationTitle("Crear cuenta")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func signUp() {
        guard canSubmit else { return }
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await session.signUp(email: email, password: password)
            } catch {
                errorMessage = AccountErrorMessage.message(for: error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
    .environment(AccountSession(client: nil))
}
