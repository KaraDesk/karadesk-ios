import Foundation

struct BootRequest: Encodable, Sendable {
    struct Device: Encodable, Sendable, Equatable {
        var os: String
        var osVersion: String
        var deviceModel: String
        var appVersion: String?
        var sdkVersion: String
        var language: String?
        var timezone: String
    }

    var spaceId: String
    var appId: String
    var visitorId: String
    var userId: String?
    var email: String?
    var name: String?
    var phone: String?
    var avatar: String?
    var signedUpAt: Int?
    var userHash: String?
    var device: Device
}

struct BootResponse: Decodable, Sendable {
    struct App: Decodable, Sendable, Equatable {
        var id: String
        var name: String
    }

    struct Space: Decodable, Sendable, Equatable {
        var name: String
        var avatarURL: URL?

        private enum CodingKeys: String, CodingKey {
            case name
            case avatar
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = container.decode(.name, default: "")
            avatarURL = container.decodeURL(.avatar)
        }
    }

    struct Identity: Decodable, Sendable, Equatable {
        enum Kind: String, Decodable, Sendable {
            case user
            case visitor
        }

        var type: Kind
        var verified: Bool
        var verificationRequired: Bool
    }

    var token: String
    var expiresAt: Date
    var app: App
    var space: Space
    var settings: MessengerSettings
    var identity: Identity
    var team: [Person]
    var contact: Contact?

    private enum CodingKeys: String, CodingKey {
        case token
        case expiresAt
        case app
        case space
        case settings
        case identity
        case team
        case contact
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decode(String.self, forKey: .token)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        app = try container.decode(App.self, forKey: .app)
        space = try container.decode(Space.self, forKey: .space)
        settings = try container.decode(MessengerSettings.self, forKey: .settings)
        identity = container.decode(.identity, default: Identity(type: .visitor, verified: false, verificationRequired: false))
        team = container.decodeLossyArray(.team)
        contact = container.decodeLenient(.contact)
    }
}

struct Contact: Decodable, Sendable, Equatable {
    enum Role: String, Decodable, Sendable {
        case user
        case lead
    }

    var id: String
    var role: Role
    var name: String?
    var email: String?
    var avatarURL: URL?

    private enum CodingKeys: String, CodingKey {
        case id
        case role
        case name
        case email
        case avatar
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        role = container.decode(.role, default: .lead)
        name = container.decodeLenient(.name)
        email = container.decodeLenient(.email)
        avatarURL = container.decodeURL(.avatar)
    }
}

struct Person: Decodable, Sendable, Hashable, Identifiable {
    var id: Int
    var name: String?
    var avatarURL: URL?
    var lastActiveAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatar
        case lastActiveAt
    }

    init(id: Int, name: String?, avatarURL: URL?, lastActiveAt: Date?) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.lastActiveAt = lastActiveAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = container.decodeLenient(.name)
        avatarURL = container.decodeURL(.avatar)
        lastActiveAt = container.decodeLenient(.lastActiveAt)
    }

    func isActive(at now: Date = .now) -> Bool {
        guard let lastActiveAt else {
            return false
        }

        return now.timeIntervalSince(lastActiveAt) <= 15 * 60
    }
}
