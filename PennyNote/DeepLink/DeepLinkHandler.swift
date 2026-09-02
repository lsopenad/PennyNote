import Foundation

enum DeepLinkHandler {
    static func handle(_ url: URL, router: AppRouter) {
        guard url.scheme == "pennynote", url.host == "add" else { return }
        router.presentAdd()
    }
}
