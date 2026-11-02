import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var searchAnimation
    @State private var isSearchActive = false

    @State private var filter = ExpenseFilter()
    // Último gasto borrado deslizando, mientras se puede deshacer desde el aviso.
    @State private var recentDeletion: DeletedExpense?

    var body: some View {
        @Bindable var router = router
        ZStack {
            NavigationStack(path: $router.navigationPath) {
                ZStack(alignment: .bottom) {
                    ExpenseDayList(
                        filter: filter,
                        onShowNeedsDetails: { filter = ExpenseFilter(onlyNeedsDetails: true) },
                        onDeleted: { deleted in
                            withAnimation(.snappy) { recentDeletion = deleted }
                        }
                    )

                    VStack(spacing: 0) {
                        if let recentDeletion {
                            UndoDeletionBanner(
                                deleted: recentDeletion,
                                onUndo: { undo(recentDeletion) },
                                onDismiss: dismissUndo
                            )
                            .padding(.horizontal, 16)
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        }

                        addButton
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                // El aviso solo tiene sentido viendo la lista: se cierra al ir a Estadísticas o Ajustes.
                .onDisappear(perform: dismissUndo)
                .navigationTitle("PennyNote")
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .statistics:
                        StatisticsView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.snappy) { isSearchActive = true }
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .matchedGeometryEffect(id: "searchAnchor", in: searchAnimation)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ExpenseFilterMenu(filter: $filter)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .opacity(isSearchActive ? 0 : 1)

            if isSearchActive {
                ExpenseSearchOverlay(
                    namespace: searchAnimation,
                    onSelect: { expense in
                        withAnimation(.snappy) { isSearchActive = false }
                        router.presentEdit(expense)
                    },
                    onCancel: {
                        withAnimation(.snappy) { isSearchActive = false }
                    }
                )
                .zIndex(1)
            }
        }
        // La búsqueda solo se abre desde la lista, así que si cambia la ruta con ella abierta es por
        // un enlace (el widget abre Estadísticas). Se cierra para que no tape la pantalla de destino.
        .onChange(of: router.navigationPath) { _, path in
            if !path.isEmpty, isSearchActive {
                isSearchActive = false
            }
        }
        // También al abrir la búsqueda o un formulario, y al pasar la app a segundo plano.
        .onChange(of: isSearchActive) { _, isActive in
            if isActive { dismissUndo() }
        }
        .onChange(of: router.isAddExpensePresented) { _, isPresented in
            if isPresented { dismissUndo() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { dismissUndo() }
        }
    }

    private func undo(_ deleted: DeletedExpense) {
        ExpenseRepository.restoreExpense(deleted, context: modelContext)
        dismissUndo()
    }

    private func dismissUndo() {
        guard recentDeletion != nil else { return }
        withAnimation(.snappy) { recentDeletion = nil }
    }

    private var addButton: some View {
        Button(action: router.presentAdd) {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.tint, in: Circle())
                .shadow(radius: 4, y: 2)
        }
        .padding(20)
    }
}
