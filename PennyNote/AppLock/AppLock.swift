import Foundation
import Observation

// Bloqueo de la app con Face ID, Touch ID o el código del iPhone. Es un ajuste de este iPhone: no se
// sincroniza con la cuenta y se apaga al cerrar sesión. Recibe el UserDefaults y el autenticador para
// poder probarlo sin Face ID.
@MainActor
@Observable
final class AppLock {
    static let shared = AppLock(defaults: .standard, authenticator: LocalDeviceAuthenticator())

    private(set) var isEnabled: Bool
    var timeout: AppLockTimeout {
        didSet { defaults.set(timeout.rawValue, forKey: Keys.timeout) }
    }
    // Se vuelve a mirar al volver a la app, por si se ha puesto o quitado el código en los Ajustes de iOS.
    private(set) var method: DeviceAuthMethod
    // Hay que autenticarse para ver la app.
    private(set) var isLocked: Bool
    // La app está tapada: bloqueada o en segundo plano, para que la miniatura del selector de apps no
    // muestre gastos.
    private(set) var isShielded: Bool {
        didSet {
            if isShielded != oldValue { onShieldChange?() }
        }
    }
    private(set) var isAuthenticating = false

    // AppLockShield, que pone y quita la ventana que tapa la app. Se avisa en el momento y no al
    // observar el cambio: al pasar a segundo plano, iOS hace la miniatura enseguida.
    @ObservationIgnored var onShieldChange: (() -> Void)?
    // El desbloqueo que se lanza solo al volver a la app; los tests lo esperan.
    @ObservationIgnored private(set) var automaticUnlock: Task<Void, Never>?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let authenticator: DeviceAuthenticator
    @ObservationIgnored private var backgroundedAt: Date?
    // Face ID salta solo al abrir la app o al volver de segundo plano, no cada vez que se activa: el
    // propio aviso de Face ID la desactiva y, al cancelarlo, se volvería a pedir sin fin.
    @ObservationIgnored private var promptsOnActivation: Bool
    // Cuenta las veces que la app pasa a segundo plano, para descartar un desbloqueo que termina
    // cuando ya se ha vuelto a salir de ella.
    @ObservationIgnored private var backgroundCount = 0

    private enum Keys {
        static let isEnabled = "appLock.isEnabled"
        static let timeout = "appLock.timeout"
    }

    init(defaults: UserDefaults, authenticator: DeviceAuthenticator) {
        self.defaults = defaults
        self.authenticator = authenticator
        let isEnabled = defaults.bool(forKey: Keys.isEnabled)
        let method = authenticator.availableMethod()
        let isLocked = isEnabled && method != .none
        self.isEnabled = isEnabled
        timeout = (defaults.object(forKey: Keys.timeout) as? Int).flatMap(AppLockTimeout.init(rawValue:)) ?? .oneMinute
        self.method = method
        self.isLocked = isLocked
        isShielded = isLocked
        promptsOnActivation = isLocked
    }

    var canAuthenticate: Bool {
        method != .none
    }

    // MARK: - Ciclo de vida de la escena

    func sceneDidEnterBackground(now: Date = .now) {
        guard isEnabled else { return }
        backgroundCount += 1
        if !isLocked {
            backgroundedAt = now
        }
        promptsOnActivation = true
        isShielded = true
    }

    func sceneDidBecomeActive(now: Date = .now) {
        method = authenticator.availableMethod()
        let backgroundedAt = self.backgroundedAt
        self.backgroundedAt = nil

        // Sin código en el iPhone no hay con qué desbloquear: se abre sin bloqueo y vuelve a bloquearse
        // cuando se ponga otra vez.
        guard isEnabled, canAuthenticate else {
            open()
            return
        }
        if let backgroundedAt, Self.hasExpired(since: backgroundedAt, now: now, timeout: timeout) {
            isLocked = true
        }
        guard isLocked else {
            open()
            return
        }
        guard promptsOnActivation else { return }
        promptsOnActivation = false
        automaticUnlock = Task { await unlock() }
    }

    // MARK: - Acciones

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        let backgroundCount = backgroundCount
        isAuthenticating = true
        let result = await authenticator.authenticate(reason: String(localized: "Desbloquea PennyNote para ver tus gastos."))
        isAuthenticating = false
        guard backgroundCount == self.backgroundCount else { return }
        switch result {
        case .success, .unavailable:
            open()
        case .failure:
            break
        }
    }

    // Al activarlo se pide autenticarse una vez, para confirmar que funciona en este iPhone.
    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled, !isAuthenticating else { return }
        if enabled {
            isAuthenticating = true
            let result = await authenticator.authenticate(reason: String(localized: "Confirma que quieres activar el bloqueo de PennyNote."))
            isAuthenticating = false
            guard result == .success else { return }
        }
        isEnabled = enabled
        defaults.set(enabled, forKey: Keys.isEnabled)
    }

    // Al cerrar sesión o borrar la cuenta: la siguiente cuenta empieza sin bloqueo.
    func reset() {
        isEnabled = false
        timeout = .oneMinute
        defaults.removeObject(forKey: Keys.isEnabled)
        defaults.removeObject(forKey: Keys.timeout)
        backgroundedAt = nil
        open()
    }

    // MARK: - Privado

    private func open() {
        isLocked = false
        isShielded = false
    }

    // Con el reloj atrasado (now anterior a la salida) también se bloquea.
    static func hasExpired(since backgroundedAt: Date, now: Date, timeout: AppLockTimeout) -> Bool {
        now < backgroundedAt || now.timeIntervalSince(backgroundedAt) >= timeout.seconds
    }
}
