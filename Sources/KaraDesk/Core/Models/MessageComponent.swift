import Foundation

struct MessageComponent: Decodable, Sendable, Equatable, Identifiable {
    enum Content: Sendable, Equatable {
        case buttons(Buttons)
        case articles([Article])
        case input(Input)
        case card(Card)
        case unknown(String)
    }

    struct Answer: Decodable, Sendable, Equatable {
        var buttonID: String?
        var value: JSONValue?
        var answeredAt: Date?

        private enum CodingKeys: String, CodingKey {
            case buttonId
            case value
            case answeredAt
        }

        init(buttonID: String?, value: JSONValue?, answeredAt: Date?) {
            self.buttonID = buttonID
            self.value = value
            self.answeredAt = answeredAt
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            buttonID = container.decodeLenient(.buttonId)
            value = container.decodeLenient(.value)
            answeredAt = container.decodeLenient(.answeredAt)
        }

        var displayValue: String? {
            switch value {
            case let .string(text):
                return text
            case let .number(number):
                return number.rounded() == number && abs(number) < 1e15 ? String(Int64(number)) : String(number)
            case let .bool(flag):
                return String(flag)
            default:
                return nil
            }
        }
    }

    struct Action: Decodable, Sendable, Equatable {
        enum Kind: Sendable, Equatable {
            case resolve
            case handoff
            case openURL
            case goto
            case event
            case other(String)

            init(rawValue: String) {
                switch rawValue {
                case "resolve":
                    self = .resolve
                case "handoff":
                    self = .handoff
                case "open_url":
                    self = .openURL
                case "goto":
                    self = .goto
                case "event":
                    self = .event
                default:
                    self = .other(rawValue)
                }
            }
        }

        var kind: Kind
        var url: URL?
        var step: String?
        var name: String?

        private enum CodingKeys: String, CodingKey {
            case type
            case url
            case step
            case name
        }

        init(kind: Kind, url: URL? = nil, step: String? = nil, name: String? = nil) {
            self.kind = kind
            self.url = url
            self.step = step
            self.name = name
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            kind = Kind(rawValue: container.decode(.type, default: ""))
            url = container.decodeURL(.url)
            step = container.decodeLenient(.step)
            name = container.decodeLenient(.name)
        }
    }

    struct Button: Decodable, Sendable, Equatable, Identifiable {
        enum Style: String, Decodable, Sendable {
            case primary
            case secondary
        }

        var id: String
        var label: String
        var value: String?
        var style: Style
        var echo: Bool
        var action: Action

        private enum CodingKeys: String, CodingKey {
            case id
            case label
            case value
            case style
            case echo
            case action
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            label = container.decode(.label, default: "")
            value = container.decodeLenient(.value)
            style = container.decode(.style, default: .secondary)
            echo = container.decode(.echo, default: false)
            action = container.decode(.action, default: Action(kind: .other("")))
        }

        var opensURL: URL? {
            guard action.kind == .openURL, let url = action.url, let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
                return nil
            }

            return url
        }
    }

    struct Buttons: Sendable, Equatable {
        enum Layout: String, Decodable, Sendable {
            case stack
            case row
        }

        var prompt: String?
        var layout: Layout
        var buttons: [Button]
    }

    struct Article: Decodable, Sendable, Equatable, Identifiable {
        var id: String
        var title: String
        var description: String?
        var url: URL?
        var helpCenterID: Int?

        private enum CodingKeys: String, CodingKey {
            case id
            case title
            case description
            case url
            case helpCenterId
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let number = container.decodeLenient(.id) as Int? {
                id = String(number)
            } else {
                id = try container.decode(String.self, forKey: .id)
            }

            title = container.decode(.title, default: "")
            description = container.decodeLenient(.description)
            url = container.decodeURL(.url)
            helpCenterID = container.decodeLenient(.helpCenterId)
        }

        var articleID: Int? {
            Int(id)
        }
    }

    struct Option: Decodable, Sendable, Equatable, Identifiable {
        var value: String
        var label: String

        var id: String {
            value
        }

        private enum CodingKeys: String, CodingKey {
            case value
            case label
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let number = container.decodeLenient(.value) as Int? {
                value = String(number)
            } else {
                value = try container.decode(String.self, forKey: .value)
            }

            label = container.decode(.label, default: value)
        }
    }

    struct Input: Sendable, Equatable {
        enum Kind: String, Decodable, Sendable {
            case text
            case email
            case phone
            case number
            case select
        }

        var label: String
        var kind: Kind
        var placeholder: String?
        var required: Bool
        var options: [Option]
        var saveTo: String?
        var echo: Bool
        var action: Action?

        func label(for answer: Answer) -> String? {
            guard let value = answer.displayValue else {
                return nil
            }

            return options.first { $0.value == value }?.label ?? value
        }
    }

    struct Card: Sendable, Equatable {
        var title: String
        var body: String?
        var imageURL: URL?
        var buttons: [Button]
    }

    var id: String
    var fallbackText: String?
    var answer: Answer?
    var content: Content

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case fallbackText
        case answer
        case prompt
        case layout
        case buttons
        case articles
        case label
        case kind
        case placeholder
        case required
        case options
        case saveTo
        case echo
        case action
        case title
        case body
        case imageUrl
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = container.decode(.type, default: "")
        id = try container.decode(String.self, forKey: .id)
        fallbackText = (container.decodeLenient(.fallbackText) as String?).flatMap { $0.isEmpty ? nil : $0 }
        answer = container.decodeLenient(.answer)

        switch type {
        case "buttons":
            content = .buttons(Buttons(
                prompt: container.decodeLenient(.prompt),
                layout: container.decode(.layout, default: .stack),
                buttons: container.decodeLossyArray(.buttons)
            ))
        case "articles":
            content = .articles(container.decodeLossyArray(.articles))
        case "input":
            content = .input(Input(
                label: container.decode(.label, default: ""),
                kind: container.decode(.kind, default: .text),
                placeholder: container.decodeLenient(.placeholder),
                required: container.decode(.required, default: false),
                options: container.decodeLossyArray(.options),
                saveTo: container.decodeLenient(.saveTo),
                echo: container.decode(.echo, default: false),
                action: container.decodeLenient(.action)
            ))
        case "card":
            content = .card(Card(
                title: container.decode(.title, default: ""),
                body: container.decodeLenient(.body),
                imageURL: container.decodeURL(.imageUrl).flatMap { $0.scheme?.lowercased() == "https" ? $0 : nil },
                buttons: container.decodeLossyArray(.buttons)
            ))
        default:
            content = .unknown(type)
        }
    }

    var isRenderable: Bool {
        switch content {
        case let .buttons(buttons):
            return !buttons.buttons.isEmpty
        case let .articles(articles):
            return !articles.isEmpty
        case .input:
            return true
        case .card:
            return true
        case .unknown:
            return fallbackText != nil
        }
    }

    var isAnswered: Bool {
        answer != nil
    }

    var previewText: String? {
        switch content {
        case let .buttons(buttons):
            return buttons.prompt ?? fallbackText
        case let .input(input):
            return input.label.isEmpty ? fallbackText : input.label
        case let .card(card):
            return card.title.isEmpty ? fallbackText : card.title
        case .articles, .unknown:
            return fallbackText
        }
    }
}

struct ComponentInteraction: Encodable, Sendable, Equatable {
    var componentId: String
    var buttonId: String?
    var value: JSONValue?

    static func button(_ buttonID: String, in componentID: String) -> Self {
        ComponentInteraction(componentId: componentID, buttonId: buttonID, value: nil)
    }

    static func value(_ value: JSONValue, in componentID: String) -> Self {
        ComponentInteraction(componentId: componentID, buttonId: nil, value: value)
    }
}

struct InteractionResult: Decodable, Sendable {
    var message: Message
    var reply: Message?

    private enum CodingKeys: String, CodingKey {
        case message
        case reply
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(Message.self, forKey: .message)
        reply = container.decodeLenient(.reply)
    }
}
