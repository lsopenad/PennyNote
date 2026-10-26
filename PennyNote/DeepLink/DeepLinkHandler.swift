import Foundation

enum DeepLinkHandler {
    static func handle(_ url: URL, router: AppRouter) {
        guard url.scheme == DeepLinkURL.scheme, url.host == DeepLinkURL.addExpenseHost else { return }
        router.presentAdd()
    }
}
