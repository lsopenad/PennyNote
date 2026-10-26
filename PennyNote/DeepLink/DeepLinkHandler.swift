import Foundation

enum DeepLinkHandler {
    static func handle(_ url: URL, router: AppRouter) {
        guard url.scheme == DeepLinkURL.scheme else { return }
        switch url.host {
        case DeepLinkURL.addExpenseHost:
            router.presentAdd()
        case DeepLinkURL.statisticsHost:
            router.presentStatistics()
        default:
            break
        }
    }
}
