import Observation
import SwiftUI

@MainActor
@Observable
final class MessengerRouter {
    enum Tab: Hashable, CaseIterable {
        case home
        case messages
        case help
    }

    enum Route: Hashable {
        case conversation(id: Int?, draft: String?)
        case collection(helpCenterID: Int, collectionID: Int, title: String)
        case article(helpCenterID: Int?, articleID: Int)
    }

    let style: KaraDesk.PresentationStyle
    var tab: Tab = .home
    private(set) var root: Route?
    var homePath: [Route] = []
    var messagesPath: [Route] = []
    var helpPath: [Route] = []
    var helpQuery = ""

    init(destination: KaraDesk.Destination = .home, style: KaraDesk.PresentationStyle = .standard) {
        self.style = style
        open(destination)
    }

    func open(_ destination: KaraDesk.Destination) {
        switch destination {
        case .home:
            show(.home, path: [])
        case .messages:
            show(.messages, path: [])
        case .helpCenter:
            show(.help, path: [])
        case let .newConversation(message):
            show(.messages, path: [.conversation(id: nil, draft: message)])
        case let .conversation(id):
            show(.messages, path: [.conversation(id: id, draft: nil)])
        case let .article(id):
            show(.help, path: [.article(helpCenterID: nil, articleID: id)])
        }
    }

    func search(_ query: String) {
        helpQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        helpPath = []
        tab = .help
    }

    func push(_ route: Route) {
        path(for: tab).wrappedValue.append(route)
    }

    func replaceTop(with route: Route) {
        var current = path(for: tab).wrappedValue

        if current.isEmpty, root != nil {
            root = route
            return
        }

        if current.isEmpty {
            current = [route]
        } else {
            current[current.count - 1] = route
        }

        path(for: tab).wrappedValue = current
    }

    func path(for tab: Tab) -> Binding<[Route]> {
        switch tab {
        case .home:
            Binding(get: { self.homePath }, set: { self.homePath = $0 })
        case .messages:
            Binding(get: { self.messagesPath }, set: { self.messagesPath = $0 })
        case .help:
            Binding(get: { self.helpPath }, set: { self.helpPath = $0 })
        }
    }

    private func show(_ tab: Tab, path: [Route]) {
        self.tab = tab

        if style == .standalone {
            root = path.first
            self.path(for: tab).wrappedValue = Array(path.dropFirst())
        } else {
            root = nil
            self.path(for: tab).wrappedValue = path
        }
    }
}
