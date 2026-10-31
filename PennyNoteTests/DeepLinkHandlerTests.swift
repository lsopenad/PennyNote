import Foundation
import Testing
@testable import PennyNote

@MainActor
struct DeepLinkHandlerTests {
    // Los widgets de inicio abren Estadísticas, y tocarlos otra vez no la apila de nuevo.
    @Test func statisticsLinkOpensStatisticsOnce() {
        let router = AppRouter()

        DeepLinkHandler.handle(DeepLinkURL.statistics, router: router)
        DeepLinkHandler.handle(DeepLinkURL.statistics, router: router)

        #expect(router.navigationPath == [.statistics])
        #expect(!router.isAddExpensePresented)
    }

    // El widget de la pantalla de bloqueo abre "Añadir gasto".
    @Test func addExpenseLinkPresentsTheForm() {
        let router = AppRouter()

        DeepLinkHandler.handle(DeepLinkURL.addExpense, router: router)

        #expect(router.isAddExpensePresented)
        #expect(router.expenseToEdit == nil)
        #expect(router.navigationPath.isEmpty)
    }

    // Un formulario abierto no se cierra al llegar a Estadísticas desde un widget.
    @Test func statisticsLinkKeepsAnOpenForm() {
        let router = AppRouter()
        router.presentAdd()

        DeepLinkHandler.handle(DeepLinkURL.statistics, router: router)

        #expect(router.isAddExpensePresented)
        #expect(router.navigationPath == [.statistics])
    }

    @Test func ignoresOtherSchemes() {
        let router = AppRouter()

        DeepLinkHandler.handle(URL(string: "https://stats")!, router: router)

        #expect(router.navigationPath.isEmpty)
        #expect(!router.isAddExpensePresented)
    }
}
