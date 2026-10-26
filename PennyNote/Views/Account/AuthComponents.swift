import SwiftUI

// Piezas comunes de las pantallas de cuenta.

struct AuthHeader: View {
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "wallet.bifold.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.brand)
            Text("PennyNote")
                .font(.title.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct EmailField: View {
    @Binding var email: String

    var body: some View {
        TextField("Email", text: $email)
            // .username y no .emailAddress: es lo que usa el autorrelleno de contraseñas para asociarlas.
            .textContentType(.username)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}

struct AuthSubmitButton: View {
    let title: String
    let isWorking: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                if isWorking {
                    ProgressView()
                } else {
                    Text(title).bold()
                }
                Spacer()
            }
        }
    }
}

struct AuthErrorSection: View {
    let message: String?

    var body: some View {
        if let message {
            Section {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
    }
}
