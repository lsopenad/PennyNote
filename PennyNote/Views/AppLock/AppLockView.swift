import SwiftUI

// Lo que se ve encima de la app mientras está tapada (AppLockShield). En segundo plano solo el nombre;
// bloqueada, además el botón para desbloquear si se ha cancelado Face ID.
struct AppLockView: View {
    let lock: AppLock

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(verbatim: "PennyNote")
                .font(.largeTitle.bold())

            if lock.isLocked {
                Text("PennyNote está bloqueada")
                    .foregroundStyle(.secondary)

                Button("Desbloquear", systemImage: unlockSymbol) {
                    Task { await lock.unlock() }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
                .opacity(lock.isAuthenticating ? 0 : 1)
                .disabled(lock.isAuthenticating)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var unlockSymbol: String {
        switch lock.method {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .passcode, .none: "lock.open"
        }
    }
}

#Preview {
    AppLockView(lock: .shared)
}
