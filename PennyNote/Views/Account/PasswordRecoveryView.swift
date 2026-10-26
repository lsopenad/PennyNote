import SwiftUI

// Recuperación con un código de un solo uso que llega por email (no un enlace: la app no tiene web).
struct PasswordRecoveryView: View {
    @Environment(AccountSession.self) private var session

    private enum Step {
        case requestCode
        case enterCode
    }

    @State private var step = Step.requestCode
    @State private var email: String
    @State private var code = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    // El código ya se ha aceptado (hay sesión): si falla el cambio de contraseña, solo se reintenta eso.
    @State private var isCodeVerified = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    init(initialEmail: String = "") {
        _email = State(initialValue: initialEmail)
    }

    private var trimmedCode: String {
        code.filter(\.isNumber)
    }

    private var canRequestCode: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !isWorking
    }

    private var canChangePassword: Bool {
        (isCodeVerified || trimmedCode.count >= 6)
            && PasswordRules.isValid(password)
            && password == passwordConfirmation
            && !isWorking
    }

    var body: some View {
        Form {
            switch step {
            case .requestCode:
                requestCodeSections
            case .enterCode:
                enterCodeSections
            }

            AuthErrorSection(message: errorMessage)
        }
        .navigationTitle("Recuperar contraseña")
        .navigationBarTitleDisplayMode(.inline)
        // Si se sale a medias tras validar el código, se entra en la app con la contraseña de antes.
        .onDisappear { session.isRecoveringPassword = false }
    }

    @ViewBuilder
    private var requestCodeSections: some View {
        Section {
            EmailField(email: $email)
                .submitLabel(.send)
                .onSubmit(requestCode)
        } footer: {
            Text("Te enviaremos un código de 6 dígitos para poner una contraseña nueva.")
        }

        Section {
            AuthSubmitButton(title: "Enviar código", isWorking: isWorking, action: requestCode)
                .disabled(!canRequestCode)
        }
    }

    @ViewBuilder
    private var enterCodeSections: some View {
        if !isCodeVerified {
            Section {
                TextField("Código", text: $code)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .font(.title3.monospacedDigit())
            } footer: {
                Text(infoMessage ?? "")
            }
        }

        Section {
            SecureField("Contraseña nueva", text: $password)
                .textContentType(.newPassword)
            SecureField("Repite la contraseña", text: $passwordConfirmation)
                .textContentType(.newPassword)
        } footer: {
            if !passwordConfirmation.isEmpty && password != passwordConfirmation {
                Text("Las contraseñas no coinciden.").foregroundStyle(.red)
            } else {
                Text("Al menos \(PasswordRules.minimumLength) caracteres.")
            }
        }

        Section {
            AuthSubmitButton(title: "Cambiar contraseña", isWorking: isWorking, action: changePassword)
                .disabled(!canChangePassword)
            if !isCodeVerified {
                Button("Enviar otro código", action: requestCode)
                    .disabled(isWorking)
            }
        }
    }

    private func requestCode() {
        guard canRequestCode else { return }
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await session.sendPasswordRecoveryCode(email: email)
                infoMessage = "Si hay una cuenta con \(email.trimmingCharacters(in: .whitespaces)), te llegará un código en unos minutos. Mira también en spam."
                step = .enterCode
            } catch {
                errorMessage = AccountErrorMessage.message(for: error)
            }
        }
    }

    private func changePassword() {
        guard canChangePassword else { return }
        isWorking = true
        errorMessage = nil
        session.isRecoveringPassword = true
        Task {
            defer { isWorking = false }
            do {
                if !isCodeVerified {
                    try await session.verifyPasswordRecoveryCode(email: email, code: trimmedCode)
                    isCodeVerified = true
                }
                try await session.updatePassword(password)
                // Con la sesión ya iniciada, esto hace que RootView pase a la app.
                session.isRecoveringPassword = false
            } catch {
                if !isCodeVerified {
                    session.isRecoveringPassword = false
                }
                errorMessage = AccountErrorMessage.message(for: error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PasswordRecoveryView()
    }
    .environment(AccountSession(client: nil))
}
