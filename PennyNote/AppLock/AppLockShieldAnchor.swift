import SwiftUI
import UIKit

// Vista vacía detrás de RootView que da a AppLockShield la escena de la ventana de la app.
struct AppLockShieldAnchor: UIViewRepresentable {
    func makeUIView(context: Context) -> AnchorView {
        AnchorView()
    }

    func updateUIView(_ uiView: AnchorView, context: Context) {}

    final class AnchorView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) no se usa")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let scene = window?.windowScene {
                AppLockShield.shared.attach(to: scene)
            }
        }
    }
}
