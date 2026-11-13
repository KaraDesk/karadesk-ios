import Foundation

struct HelpCollection: Decodable, Sendable, Equatable, Identifiable {
    var id: Int
    var parentId: Int?
    var name: String
    var description: String?
    var position: Int
    var articleCount: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case parentId
        case name
        case description
        case position
        case articleCount
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        parentId = container.decodeLenient(.parentId)
        name = container.decode(.name, default: "")
        description = container.decodeLenient(.description)
        position = container.decode(.position, default: 0)
        articleCount = container.decode(.articleCount, default: 0)
    }
}

struct HelpArticleSummary: Decodable, Sendable, Equatable, Identifiable {
    var id: Int
    var title: String
    var description: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = container.decode(.title, default: "")
        description = container.decodeLenient(.description)
    }
}

struct HelpArticle: Decodable, Sendable, Equatable, Identifiable {
    var id: Int
    var title: String
    var description: String?
    var body: RichNode?
    var author: Person?
    var updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case body
        case author
        case updatedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = container.decode(.title, default: "")
        description = container.decodeLenient(.description)
        body = container.decodeLenient(.body)
        author = container.decodeLenient(.author)
        updatedAt = container.decodeLenient(.updatedAt)
    }
}

enum ArticleReaction: String, Codable, Sendable, CaseIterable {
    case sad
    case neutral
    case happy
}

struct RichNode: Decodable, Sendable, Equatable {
    struct Mark: Decodable, Sendable, Equatable {
        var type: String
        var attrs: [String: JSONValue]

        private enum CodingKeys: String, CodingKey {
            case type
            case attrs
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(String.self, forKey: .type)
            attrs = container.decode(.attrs, default: [:])
        }
    }

    var type: String
    var attrs: [String: JSONValue]
    var content: [RichNode]
    var text: String?
    var marks: [Mark]

    private enum CodingKeys: String, CodingKey {
        case type
        case attrs
        case content
        case text
        case marks
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.decode(.type, default: "")
        attrs = container.decode(.attrs, default: [:])
        content = container.decodeLossyArray(.content)
        text = container.decodeLenient(.text)
        marks = container.decodeLossyArray(.marks)
    }
}
