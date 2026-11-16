import Foundation

struct Message: Decodable, Sendable, Equatable, Identifiable {
    enum Kind: Equatable, Sendable {
        case comment
        case replyTime
        case csat
        case other(String)

        init(rawValue: String) {
            switch rawValue {
            case "comment":
                self = .comment
            case "reply_time":
                self = .replyTime
            case "csat":
                self = .csat
            default:
                self = .other(rawValue)
            }
        }
    }

    struct Author: Decodable, Sendable, Equatable {
        enum Kind: String, Decodable, Sendable {
            case contact
            case user
            case bot
        }

        var kind: Kind
        var name: String?
        var avatarURL: URL?

        private enum CodingKeys: String, CodingKey {
            case type
            case name
            case avatar
        }

        init(kind: Kind, name: String?, avatarURL: URL?) {
            self.kind = kind
            self.name = name
            self.avatarURL = avatarURL
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            kind = container.decode(.type, default: .user)
            name = container.decodeLenient(.name)
            avatarURL = container.decodeURL(.avatar)
        }
    }

    struct Metadata: Decodable, Sendable, Equatable {
        var rating: Int?
        var remark: String?
        var ratedAt: Date?
        var expiresAt: Date?
        var lockUntil: Date?
        var teammateName: String?
        var open: Bool?
        var replyTime: String?
        var nextOpenAt: Date?

        private enum CodingKeys: String, CodingKey {
            case rating
            case remark
            case ratedAt
            case expiresAt
            case lockUntil
            case teammateName
            case open
            case replyTime
            case nextOpenAt
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            rating = container.decodeLenient(.rating)
            remark = container.decodeLenient(.remark)
            ratedAt = container.decodeLenient(.ratedAt)
            expiresAt = container.decodeLenient(.expiresAt)
            lockUntil = container.decodeLenient(.lockUntil)
            teammateName = container.decodeLenient(.teammateName)
            open = container.decodeLenient(.open)
            replyTime = container.decodeLenient(.replyTime)
            nextOpenAt = container.decodeLenient(.nextOpenAt)
        }
    }

    var id: String
    var conversationId: Int
    var kind: Kind
    var author: Author
    var body: String
    var attachments: [MessageAttachment]
    var components: [MessageComponent]
    var metadata: Metadata?
    var createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case conversationId
        case type
        case author
        case body
        case attachments
        case components
        case metadata
        case createdAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        conversationId = try container.decode(Int.self, forKey: .conversationId)
        kind = Kind(rawValue: container.decode(.type, default: "comment"))
        author = try container.decode(Author.self, forKey: .author)
        body = container.decode(.body, default: "")
        attachments = container.decodeLossyArray(.attachments)
        components = container.decodeLossyArray(.components)
        metadata = container.decodeLenient(.metadata)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    var isFromContact: Bool {
        author.kind == .contact
    }

    var previewText: String {
        guard body.isEmpty else {
            return body
        }

        return components.lazy.compactMap(\.previewText).first ?? ""
    }
}

enum MessageAttachment: Decodable, Sendable, Equatable {
    struct File: Sendable, Equatable {
        var assetID: String
        var name: String
        var contentType: String
        var byteSize: Int
        var url: URL

        enum Kind: Equatable, Sendable {
            case image
            case video
            case file
        }

        static let inlineImageTypes: Set<String> = ["image/png", "image/jpeg", "image/gif", "image/webp"]

        var kind: Kind {
            let type = contentType.lowercased()

            if Self.inlineImageTypes.contains(type) {
                return .image
            }

            if type.hasPrefix("video/") {
                return .video
            }

            return .file
        }

        var isImage: Bool {
            kind == .image
        }
    }

    struct Article: Sendable, Equatable {
        var articleID: Int
        var helpCenterID: Int?
        var title: String
        var description: String?
    }

    case file(File)
    case article(Article)
    case link(url: URL, title: String?)

    private enum CodingKeys: String, CodingKey {
        case type
        case assetId
        case name
        case contentType
        case byteSize
        case url
        case articleId
        case helpCenterId
        case title
        case description
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "file":
            guard let url = container.decodeURL(.url) else {
                throw DecodingError.dataCorruptedError(forKey: .url, in: container, debugDescription: "File without URL")
            }

            self = .file(File(
                assetID: try container.decode(String.self, forKey: .assetId),
                name: container.decode(.name, default: url.lastPathComponent),
                contentType: container.decode(.contentType, default: "application/octet-stream"),
                byteSize: container.decode(.byteSize, default: 0),
                url: url
            ))
        case "article":
            self = .article(Article(
                articleID: try container.decode(Int.self, forKey: .articleId),
                helpCenterID: container.decodeLenient(.helpCenterId),
                title: container.decode(.title, default: ""),
                description: container.decodeLenient(.description)
            ))
        case "link":
            guard let url = container.decodeURL(.url) else {
                throw DecodingError.dataCorruptedError(forKey: .url, in: container, debugDescription: "Link without URL")
            }

            self = .link(url: url, title: container.decodeLenient(.title))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unsupported attachment: \(type)")
        }
    }
}

struct UploadedFile: Decodable, Sendable, Equatable {
    var id: String
    var name: String
    var contentType: String
    var byteSize: Int
    var status: String
}

struct UploadTicket: Decodable, Sendable {
    struct Upload: Decodable, Sendable {
        var method: String
        var url: URL
        var fields: [String: String]
    }

    var asset: UploadedFile
    var upload: Upload
}
