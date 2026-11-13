import SwiftUI

struct MessengerView: View {
    let store: MessengerStore
    @State private var router: MessengerRouter
    let onClose: @MainActor @Sendable () -> Void

    @Environment(\.colorScheme) private var systemScheme

    init(store: MessengerStore, router: MessengerRouter, onClose: @escaping @MainActor @Sendable () -> Void) {
        self.store = store
        _router = State(initialValue: router)
        self.onClose = onClose
    }

    init(
        store: MessengerStore,
        destination: KaraDesk.Destination,
        style: KaraDesk.PresentationStyle = .standard,
        onClose: @escaping @MainActor @Sendable () -> Void
    ) {
        self.init(store: store, router: MessengerRouter(destination: destination, style: style), onClose: onClose)
    }

    var body: some View {
        Group {
            switch store.phase {
            case .ready:
                if router.style == .standalone {
                    standalone
                } else {
                    tabs
                }
            case let .failed(error):
                UnavailableView(error: error) {
                    Task { try? await store.start() }
                }
            case .idle, .loading:
                NavigationStack {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .closeToolbar()
                }
                .task { try? await store.start() }
            }
        }
        .environment(\.karaDeskTheme, theme)
        .environment(\.karaDeskClose, CloseAction(run: onClose))
        .tint(theme.tint)
        .preferredColorScheme(theme.colorScheme)
        .background(InterfaceStyleOverride(colorScheme: theme.colorScheme))
        .onAppear {
            store.isMessengerVisible = true
            InAppMessageCenter.shared.dismiss()
        }
        .onDisappear {
            store.isMessengerVisible = false
        }
    }

    private var theme: Theme {
        guard let settings = store.settings else {
            return .standard
        }

        let dark = settings.theme == .dark || (settings.theme == .system && systemScheme == .dark)
        return Theme(settings: settings, dark: dark)
    }

    private var showsHelp: Bool {
        store.settings?.helpCenter != nil && store.settings?.showHelp != false
    }

    // MARK: Standard

    private var tabs: some View {
        @Bindable var router = router

        return TabView(selection: $router.tab) {
            stack(.home) {
                HomeView(store: store, router: router)
            }
            .tabItem {
                Label(Strings.home, systemImage: "house")
            }
            .tag(MessengerRouter.Tab.home)

            stack(.messages) {
                ConversationListView(store: store, router: router)
            }
            .tabItem {
                Label(Strings.messages, systemImage: "bubble.left.and.bubble.right")
            }
            .badge(store.unreadConversationCount)
            .tag(MessengerRouter.Tab.messages)

            if showsHelp {
                stack(.help) {
                    HelpView(store: store, router: router)
                }
                .tabItem {
                    Label(Strings.help, systemImage: "questionmark.circle")
                }
                .tag(MessengerRouter.Tab.help)
            }
        }
    }

    // MARK: Standalone

    private var standalone: some View {
        stack(router.tab) {
            if let root = router.root {
                destination(for: root)
            } else {
                switch router.tab {
                case .home:
                    HomeView(store: store, router: router)
                case .messages:
                    ConversationListView(store: store, router: router)
                case .help:
                    HelpView(store: store, router: router)
                }
            }
        }
    }

    // MARK: Navigation

    private func stack(_ tab: MessengerRouter.Tab, @ViewBuilder root: () -> some View) -> some View {
        NavigationStack(path: router.path(for: tab)) {
            root()
                .navigationDestination(for: MessengerRouter.Route.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: MessengerRouter.Route) -> some View {
        switch route {
        case let .conversation(id, draft):
            ChatView(store: store, router: router, conversationID: id, initialDraft: draft)
        case let .collection(helpCenterID, collectionID, title):
            CollectionView(store: store, router: router, helpCenterID: helpCenterID, collectionID: collectionID, title: title)
        case let .article(helpCenterID, articleID):
            ArticleView(store: store, helpCenterID: helpCenterID, articleID: articleID)
        }
    }
}

private struct UnavailableView: View {
    let error: KaraDeskError
    let retry: () -> Void

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(Strings.messengerUnavailable, systemImage: "bubble.left.and.exclamationmark.bubble.right")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                if case .network = error {
                    Button(Strings.retry, action: retry)
                        .buttonStyle(.borderedProminent)
                }
            }
            .closeToolbar()
        }
    }
}

struct CloseAction: Sendable {
    let run: @MainActor @Sendable () -> Void

    @MainActor
    func callAsFunction() {
        run()
    }
}

private struct CloseKey: EnvironmentKey {
    static let defaultValue = CloseAction(run: {})
}

extension EnvironmentValues {
    var karaDeskClose: CloseAction {
        get { self[CloseKey.self] }
        set { self[CloseKey.self] = newValue }
    }
}

struct CloseButton: View {
    @Environment(\.karaDeskClose) private var close

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(role: .close) {
                close()
            }
            .tint(.primary)
        } else {
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .fontWeight(.semibold)
            }
            .tint(.primary)
            .accessibilityLabel(Strings.close)
        }
    }
}

extension View {
    func closeToolbar() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CloseButton()
            }
        }
    }

    func prominentButton() -> some View {
        modifier(ProminentButton())
    }

    @ViewBuilder
    func glassBar() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: .rect(cornerRadius: 24, style: .continuous))
        } else {
            background(.bar, in: .rect(cornerRadius: 24, style: .continuous))
        }
    }

    @ViewBuilder
    func glassCircle() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: .circle)
        } else {
            background(.bar, in: .circle)
        }
    }
}

struct BareToolbarItem<Content: View>: ToolbarContent {
    let placement: ToolbarItemPlacement
    @ViewBuilder var content: () -> Content

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: placement) {
                content()
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement) {
                content()
            }
        }
    }
}

private struct ProminentButton: ViewModifier {
    @Environment(\.karaDeskTheme) private var theme

    @ViewBuilder
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                content.buttonStyle(.glassProminent)
            } else {
                content
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
            }
        }
        .tint(theme.accent)
        .foregroundStyle(theme.onAccent)
    }
}
