import Foundation

struct Conversation: Decodable, Sendable, Equatable, Identifiable {
    enum State: String, Decodable, Sendable {
        case open
        case closed
        case snoozed
    }

    struct Preview: Decodable, Sendable, Equatable {
        enum AuthorKind: String, Decodable, Sendable {
            case contact
            case user
            case bot
        }

        var id: String
        var authorType: AuthorKind
        var authorName: String?
        var body: String
        var createdAt: Date

        private enum CodingKeys: String, CodingKey {
            case id
            case authorType
            case authorName
            case body
            case createdAt
        }

        init(_ message: Message) {
            id = message.id
            authorType = AuthorKind(rawValue: message.author.kind.rawValue) ?? .user
            authorName = message.author.name
            body = message.previewText
            createdAt = message.createdAt
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            authorType = container.decode(.authorType, default: .user)
            authorName = container.decodeLenient(.authorName)
            body = container.decode(.body, default: "")
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
    }

    var id: Int
    var state: State
    var title: String?
    var mergedIntoId: Int?
    var lastMessage: Preview?
    var lastMessageAt: Date?
    var unread: Bool
    var unreadCount: Int
    var closedAt: Date?
    var createdAt: Date
    var assignee: Person?

    private enum CodingKeys: String, CodingKey {
        case id
        case state
        case title
        case mergedIntoId
        case lastMessage
        case lastMessageAt
        case unread
        case unreadCount
        case closedAt
        case createdAt
        case assignee
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        state = container.decode(.state, default: .open)
        title = container.decodeLenient(.title)
        mergedIntoId = container.decodeLenient(.mergedIntoId)
        lastMessage = container.decodeLenient(.lastMessage)
        lastMessageAt = container.decodeLenient(.lastMessageAt)
        unreadCount = container.decode(.unreadCount, default: 0)
        unread = container.decode(.unread, default: unreadCount > 0)
        closedAt = container.decodeLenient(.closedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        assignee = container.decodeLenient(.assignee)
    }

    var sortDate: Date {
        lastMessageAt ?? createdAt
    }
}

struct ConversationThread: Decodable, Sendable {
    var conversation: Conversation
    var messages: [Message]

    private enum CodingKeys: String, CodingKey {
        case conversation
        case messages
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conversation = try container.decode(Conversation.self, forKey: .conversation)
        messages = container.decodeLossyArray(.messages)
    }
}

struct Page<Item: Decodable & Sendable>: Decodable, Sendable {
    var data: [Item]

    private enum CodingKeys: String, CodingKey {
        case data
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = container.decodeLossyArray(.data)
    }
}
