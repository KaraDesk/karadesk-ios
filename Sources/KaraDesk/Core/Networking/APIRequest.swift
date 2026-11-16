import Foundation

struct APIRequest<Response: Decodable & Sendable>: Sendable {
    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    var method: Method
    var path: String
    var query: [URLQueryItem] = []
    var body: (any Encodable & Sendable)?
    var requiresSession = true
}

struct EmptyBody: Encodable, Sendable {}

extension APIRequest where Response == BootResponse {
    static func boot(_ body: BootRequest) -> Self {
        APIRequest(method: .post, path: "/v1/messenger/boot", body: body, requiresSession: false)
    }
}

extension APIRequest where Response == Page<Conversation> {
    static func conversations() -> Self {
        APIRequest(method: .get, path: "/v1/messenger/conversations")
    }
}

struct OutgoingMessage: Encodable, Sendable {
    struct Attachment: Encodable, Sendable {
        var type = "file"
        var assetId: String
    }

    var body: String
    var attachments: [Attachment]?
}

extension APIRequest where Response == ConversationThread {
    static func conversation(_ id: Int) -> Self {
        APIRequest(method: .get, path: "/v1/messenger/conversations/\(id)")
    }

    static func startConversation(_ message: OutgoingMessage) -> Self {
        APIRequest(method: .post, path: "/v1/messenger/conversations", body: message)
    }
}

struct RatingInput: Encodable, Sendable {
    var messageId: String
    var rating: Int?
    var remark: String?
}

extension APIRequest where Response == Message {
    static func send(_ message: OutgoingMessage, to conversationID: Int) -> Self {
        APIRequest(method: .post, path: "/v1/messenger/conversations/\(conversationID)/messages", body: message)
    }

    static func rate(_ input: RatingInput, conversationID: Int) -> Self {
        APIRequest(method: .post, path: "/v1/messenger/conversations/\(conversationID)/rating", body: input)
    }
}

extension APIRequest where Response == InteractionResult {
    static func interact(_ interaction: ComponentInteraction, messageID: String, conversationID: Int) -> Self {
        APIRequest(method: .post, path: "/v1/messenger/conversations/\(conversationID)/messages/\(messageID)/interactions", body: interaction)
    }
}

extension APIRequest where Response == Conversation {
    static func markRead(_ conversationID: Int) -> Self {
        APIRequest(method: .post, path: "/v1/messenger/conversations/\(conversationID)/read", body: EmptyBody())
    }
}

struct UploadRequest: Encodable, Sendable {
    var filename: String
    var contentType: String
    var byteSize: Int
}

extension APIRequest where Response == UploadTicket {
    static func startUpload(_ input: UploadRequest) -> Self {
        APIRequest(method: .post, path: "/v1/messenger/attachments", body: input)
    }
}

extension APIRequest where Response == UploadedFile {
    static func completeUpload(_ assetID: String) -> Self {
        APIRequest(method: .post, path: "/v1/messenger/attachments/\(assetID)/complete", body: EmptyBody())
    }
}

struct ReactionInput: Encodable, Sendable {
    var reaction: ArticleReaction
}

struct ReactionResult: Decodable, Sendable {
    var reaction: ArticleReaction?
}

extension APIRequest where Response == ReactionResult {
    static func react(_ reaction: ArticleReaction, articleID: Int) -> Self {
        APIRequest(method: .post, path: "/v1/messenger/articles/\(articleID)/reactions", body: ReactionInput(reaction: reaction))
    }
}

extension APIRequest where Response == Page<HelpCollection> {
    static func collections(helpCenterID: Int) -> Self {
        APIRequest(method: .get, path: "/v1/public/help-centers/\(helpCenterID)/collections", requiresSession: false)
    }
}

extension APIRequest where Response == Page<HelpArticleSummary> {
    static func articles(helpCenterID: Int, collectionID: Int) -> Self {
        APIRequest(
            method: .get,
            path: "/v1/public/help-centers/\(helpCenterID)/articles",
            query: [
                URLQueryItem(name: "collection_id", value: String(collectionID)),
                URLQueryItem(name: "limit", value: "100"),
                URLQueryItem(name: "offset", value: "0"),
            ],
            requiresSession: false
        )
    }

    static func search(helpCenterID: Int, query: String) -> Self {
        APIRequest(
            method: .get,
            path: "/v1/public/help-centers/\(helpCenterID)/search",
            query: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: "20"),
                URLQueryItem(name: "offset", value: "0"),
            ],
            requiresSession: false
        )
    }
}

extension APIRequest where Response == HelpArticle {
    static func article(helpCenterID: Int, articleID: Int) -> Self {
        APIRequest(method: .get, path: "/v1/public/help-centers/\(helpCenterID)/articles/\(articleID)", requiresSession: false)
    }
}

struct PushTokenInput: Encodable, Sendable {
    var token: String
    var environment: String
}

struct PushTokenResult: Decodable, Sendable {
    var token: String
}

extension APIRequest where Response == PushTokenResult {
    static func registerPushToken(_ input: PushTokenInput) -> Self {
        APIRequest(method: .put, path: "/v1/messenger/push-token", body: input)
    }

    static func removePushToken(_ token: String) -> Self {
        APIRequest(method: .delete, path: "/v1/messenger/push-token/\(token)")
    }
}
