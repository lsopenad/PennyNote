import SwiftUI
import UIKit

// Tapa la app con una ventana propia por encima de la principal. Así quedan debajo también las hojas,
// las alertas y la hoja de compartir, que una vista de SwiftUI encima de la pantalla no taparía.
@MainActor
final class AppLockShield {
    static let shared = AppLockShield(lock: .shared)

    private let lock: AppLock
    private weak var scene: UIWindowScene?
    private var window: UIWindow?

    init(lock: AppLock) {
        self.lock = lock
        lock.onShieldChange = { [weak self] in self?.update() }
    }

    // Lo llama AppLockShieldAnchor en cuanto la ventana de la app tiene escena, antes del primer
    // fotograma: al abrir la app bloqueada no llegan a verse los gastos.
    func attach(to scene: UIWindowScene) {
        guard self.scene !== scene else { return }
        window?.isHidden = true
        window = nil
        self.scene = scene
        update()
    }

    private func update() {
        if lock.isShielded {
            show()
        } else {
            hide()
        }
    }

    private func show() {
        guard window == nil, let scene else { return }
        // El teclado va en su propia ventana, por encima de esta: se cierra para no escribir a ciegas en
        // la pantalla tapada.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: AppLockView(lock: lock))
        window.makeKeyAndVisible()
        self.window = window
    }

    private func hide() {
        guard let window else { return }
        window.isHidden = true
        self.window = nil
        scene?.windows.first { $0.windowLevel == .normal && !$0.isHidden }?.makeKey()
    }
}
