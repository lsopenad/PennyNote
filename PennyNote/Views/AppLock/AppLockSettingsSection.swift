import SwiftUI

// Ajustes → bloqueo con Face ID y cuánto tiempo puede estar la app en segundo plano sin pedirlo.
struct AppLockSettingsSection: View {
    @Environment(AppLock.self) private var lock

    var body: some View {
        @Bindable var lock = lock

        Section {
            // Al activarlo se pide Face ID: si se cancela, el interruptor vuelve a apagarse.
            Toggle(toggleTitle, isOn: Binding(
                get: { lock.isEnabled },
                set: { enabled in Task { await lock.setEnabled(enabled) } }
            ))
            .disabled(!lock.canAuthenticate || lock.isAuthenticating)

            if lock.isEnabled {
                Picker("Pedir desbloqueo", selection: $lock.timeout) {
                    ForEach(AppLockTimeout.allCases) { timeout in
                        Text(timeout.title).tag(timeout)
                    }
                }
            }
        } footer: {
            if lock.canAuthenticate {
                Text("Pide desbloquear al abrir PennyNote. Siempre puedes usar el código del iPhone.")
            } else {
                Text("Configura un código en el iPhone para usar el bloqueo.")
            }
        }
    }

    private var toggleTitle: LocalizedStringKey {
        switch lock.method {
        case .faceID: "Bloquear con Face ID"
        case .touchID: "Bloquear con Touch ID"
        case .passcode, .none: "Bloquear con el código"
        }
    }
}
