import Foundation

struct MessengerSettings: Decodable, Sendable, Equatable {
    enum Theme: String, Decodable, Sendable {
        case light
        case dark
        case system
    }

    enum HeaderText: String, Decodable, Sendable {
        case auto
        case light
        case dark
    }

    struct Background: Decodable, Sendable, Equatable {
        enum Kind: String, Decodable, Sendable {
            case solid
            case gradient
            case image
        }

        var kind: Kind
        var color: String?
        var gradientFrom: String?
        var gradientTo: String?
        var imageURL: URL?
        var fade: Bool

        static let plain = Background(kind: .solid, color: nil, gradientFrom: nil, gradientTo: nil, imageURL: nil, fade: false)

        private enum CodingKeys: String, CodingKey {
            case type
            case color
            case gradientFrom
            case gradientTo
            case image
            case fade
        }

        init(kind: Kind, color: String?, gradientFrom: String?, gradientTo: String?, imageURL: URL?, fade: Bool) {
            self.kind = kind
            self.color = color
            self.gradientFrom = gradientFrom
            self.gradientTo = gradientTo
            self.imageURL = imageURL
            self.fade = fade
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            kind = container.decode(.type, default: .solid)
            color = container.decodeLenient(.color)
            gradientFrom = container.decodeLenient(.gradientFrom)
            gradientTo = container.decodeLenient(.gradientTo)
            imageURL = nil
            fade = container.decode(.fade, default: false)
        }
    }

    struct DarkAppearance: Decodable, Sendable, Equatable {
        var color: String?
        var headerText: HeaderText?
        var background: PartialBackground?

        struct PartialBackground: Decodable, Sendable, Equatable {
            var type: Background.Kind?
            var color: String?
            var gradientFrom: String?
            var gradientTo: String?
            var fade: Bool?
        }

        static let none = DarkAppearance(color: nil, headerText: nil, background: nil)
    }

    struct Rules: Decodable, Sendable, Equatable {
        var allowNew: Bool
        var singleOpen: Bool
        var requireSearch: Bool
        var closedReplyDays: Int?

        static let standard = Rules(allowNew: true, singleOpen: false, requireSearch: false, closedReplyDays: nil)

        private enum CodingKeys: String, CodingKey {
            case allowNew
            case singleOpen
            case requireSearch
            case closedReplyDays
        }

        init(allowNew: Bool, singleOpen: Bool, requireSearch: Bool, closedReplyDays: Int?) {
            self.allowNew = allowNew
            self.singleOpen = singleOpen
            self.requireSearch = requireSearch
            self.closedReplyDays = closedReplyDays
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            allowNew = container.decode(.allowNew, default: true)
            singleOpen = container.decode(.singleOpen, default: false)
            requireSearch = container.decode(.requireSearch, default: false)
            closedReplyDays = container.decodeLenient(.closedReplyDays)
        }
    }

    struct AudienceRules: Decodable, Sendable, Equatable {
        var visitors: Rules
        var users: Rules

        static let standard = AudienceRules(visitors: .standard, users: .standard)

        private enum CodingKeys: String, CodingKey {
            case visitors
            case users
        }

        init(visitors: Rules, users: Rules) {
            self.visitors = visitors
            self.users = users
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            visitors = container.decode(.visitors, default: .standard)
            users = container.decode(.users, default: .standard)
        }
    }

    struct Availability: Decodable, Sendable, Equatable {
        var open: Bool
        var replyTime: String?
        var nextOpenAt: Date?

        private enum CodingKeys: String, CodingKey {
            case open
            case replyTime
            case nextOpenAt
        }

        init(open: Bool, replyTime: String?, nextOpenAt: Date?) {
            self.open = open
            self.replyTime = replyTime
            self.nextOpenAt = nextOpenAt
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            open = container.decode(.open, default: true)
            replyTime = container.decodeLenient(.replyTime)
            nextOpenAt = container.decodeLenient(.nextOpenAt)
        }
    }

    struct AttachmentRules: Decodable, Sendable, Equatable {
        var enabled: Bool
        var maxBytes: Int
        var accept: [String]

        static let disabled = AttachmentRules(enabled: false, maxBytes: 0, accept: [])

        private enum CodingKeys: String, CodingKey {
            case enabled
            case maxBytes
            case accept
        }

        init(enabled: Bool, maxBytes: Int, accept: [String]) {
            self.enabled = enabled
            self.maxBytes = maxBytes
            self.accept = accept
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            enabled = container.decode(.enabled, default: false)
            maxBytes = container.decode(.maxBytes, default: 0)
            accept = container.decode(.accept, default: [])
        }
    }

    var color: String
    var theme: Theme
    var logoURL: URL?
    var darkLogoURL: URL?
    var headerText: HeaderText
    var background: Background
    var darkBackgroundImageURL: URL?
    var dark: DarkAppearance
    var rules: AudienceRules
    var homeCards: [HomeCard]
    var greeting: String
    var intro: String
    var showTeam: Bool
    var showBranding: Bool
    var showHelp: Bool
    var helpCenter: HelpCenterReference?
    var helpCenters: [HelpCenterReference]
    var availability: Availability?
    var attachments: AttachmentRules

    private enum CodingKeys: String, CodingKey {
        case color
        case theme
        case logoURL = "logoUrl"
        case darkLogoURL = "darkLogoUrl"
        case headerText
        case background
        case backgroundImageURL = "backgroundImageUrl"
        case darkBackgroundImageURL = "darkBackgroundImageUrl"
        case dark
        case rules
        case homeCards
        case greeting
        case intro
        case showTeam
        case showBranding
        case showHelp
        case helpCenter
        case helpCenters
        case availability
        case attachments
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = container.decode(.color, default: "#111111")
        theme = container.decode(.theme, default: .system)
        logoURL = container.decodeURL(.logoURL)
        darkLogoURL = container.decodeURL(.darkLogoURL)
        headerText = container.decode(.headerText, default: .auto)
        background = container.decode(.background, default: .plain)
        background.imageURL = container.decodeURL(.backgroundImageURL)
        darkBackgroundImageURL = container.decodeURL(.darkBackgroundImageURL)
        dark = container.decode(.dark, default: .none)
        rules = container.decode(.rules, default: .standard)
        homeCards = container.decodeLossyArray(.homeCards)
        greeting = container.decode(.greeting, default: "")
        intro = container.decode(.intro, default: "")
        showTeam = container.decode(.showTeam, default: true)
        showBranding = container.decode(.showBranding, default: true)
        showHelp = container.decode(.showHelp, default: true)
        helpCenter = container.decodeLenient(.helpCenter)
        helpCenters = container.decodeLossyArray(.helpCenters)
        availability = container.decodeLenient(.availability)
        attachments = container.decode(.attachments, default: .disabled)
    }

    func rules(identified: Bool) -> Rules {
        identified ? rules.users : rules.visitors
    }

    func helpCenter(id: Int?) -> HelpCenterReference? {
        guard let id else {
            return helpCenter
        }

        if let helpCenter, helpCenter.id == id {
            return helpCenter
        }

        return helpCenters.first { $0.id == id }
    }
}

struct HelpCenterReference: Decodable, Sendable, Hashable {
    var id: Int
    var name: String
    var url: URL?
    var articleReactions: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case url
        case articleReactions
    }

    init(id: Int, name: String, url: URL?, articleReactions: Bool) {
        self.id = id
        self.name = name
        self.url = url
        self.articleReactions = articleReactions
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = container.decode(.name, default: "")
        url = container.decodeURL(.url)
        articleReactions = container.decode(.articleReactions, default: false)
    }
}

enum HomeCard: Decodable, Sendable, Equatable, Identifiable {
    case messages(id: String)
    case help(HelpCard)
    case link(LinkCard)
    case text(TextCard)

    struct HelpCard: Sendable, Equatable {
        var id: String
        var title: String?
        var showSearch: Bool
        var helpCenter: HelpCenterReference
        var articles: [ArticleLink]
    }

    struct ArticleLink: Decodable, Sendable, Equatable, Identifiable {
        var id: Int
        var title: String
    }

    struct LinkCard: Sendable, Equatable {
        var id: String
        var title: String
        var description: String?
        var url: URL
        var buttonLabel: String?
    }

    struct TextCard: Sendable, Equatable {
        var id: String
        var title: String?
        var body: String
    }

    var id: String {
        switch self {
        case let .messages(id):
            return id
        case let .help(card):
            return card.id
        case let .link(card):
            return card.id
        case let .text(card):
            return card.id
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case showSearch
        case helpCenter
        case articles
        case description
        case url
        case buttonLabel
        case body
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "messages":
            self = .messages(id: id)
        case "help":
            self = .help(HelpCard(
                id: id,
                title: container.decodeLenient(.title),
                showSearch: container.decode(.showSearch, default: true),
                helpCenter: try container.decode(HelpCenterReference.self, forKey: .helpCenter),
                articles: container.decodeLossyArray(.articles)
            ))
        case "link":
            guard let url = container.decodeURL(.url) else {
                throw DecodingError.dataCorruptedError(forKey: .url, in: container, debugDescription: "Missing link URL")
            }

            self = .link(LinkCard(
                id: id,
                title: container.decode(.title, default: ""),
                description: container.decodeLenient(.description),
                url: url,
                buttonLabel: container.decodeLenient(.buttonLabel)
            ))
        case "text":
            self = .text(TextCard(
                id: id,
                title: container.decodeLenient(.title),
                body: container.decode(.body, default: "")
            ))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unsupported card: \(type)")
        }
    }
}
