import Foundation

enum RealtimeEvent: Sendable, Equatable {
    case ready
    case messageCreated(Message)
    case messageUpdated(Message)
    case messageDeleted(conversationID: Int, messageID: String)
    case conversationChanged(Conversation)
    case typing(conversationID: Int, author: Message.Author)
    case unauthorized

    static func decode(_ data: Data) -> RealtimeEvent? {
        guard let envelope = try? Coding.decoder().decode(Envelope.self, from: data) else {
            return nil
        }

        return envelope.event
    }

    private struct Envelope: Decodable {
        var event: RealtimeEvent?

        private enum CodingKeys: String, CodingKey {
            case type
            case data
        }

        private struct MessagePayload: Decodable {
            var message: Message
        }

        private struct DeletedPayload: Decodable {
            var conversationId: Int
            var messageId: String
        }

        private struct ConversationPayload: Decodable {
            var conversation: Conversation
        }

        private struct TypingPayload: Decodable {
            var conversationId: Int
            var author: Message.Author
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = container.decode(.type, default: "")

            switch type {
            case "ready":
                event = .ready
            case "message.created":
                event = (container.decodeLenient(.data) as MessagePayload?).map { .messageCreated($0.message) }
            case "message.updated":
                event = (container.decodeLenient(.data) as MessagePayload?).map { .messageUpdated($0.message) }
            case "message.deleted":
                event = (container.decodeLenient(.data) as DeletedPayload?).map {
                    .messageDeleted(conversationID: $0.conversationId, messageID: $0.messageId)
                }
            case "conversation.created", "conversation.updated":
                event = (container.decodeLenient(.data) as ConversationPayload?).map { .conversationChanged($0.conversation) }
            case "typing":
                event = (container.decodeLenient(.data) as TypingPayload?).map {
                    .typing(conversationID: $0.conversationId, author: $0.author)
                }
            default:
                event = nil
            }
        }
    }
}
