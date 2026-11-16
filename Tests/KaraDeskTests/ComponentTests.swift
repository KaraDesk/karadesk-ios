import Foundation
import Testing
@testable import KaraDesk

@Suite("Message components")
struct ComponentTests {
    static let message = """
    {
      "id": "msg_k1", "conversation_id": 42, "type": "comment",
      "author": { "type": "bot", "id": "kara", "name": "Kara", "avatar": null },
      "body": "", "attachments": [],
      "components": [
        {
          "id": "c_buttons", "type": "buttons", "fallback_text": "Did that help?", "prompt": "Did that help?", "layout": "row",
          "answer": { "button_id": "yes", "value": "yes", "answered_at": "2026-11-16T10:00:00Z" },
          "buttons": [
            { "id": "yes", "label": "Yes", "value": "yes", "style": "primary", "echo": true, "action": { "type": "resolve" } },
            { "id": "no", "label": "Talk to a person", "value": null, "style": "secondary", "echo": true, "action": { "type": "handoff" } },
            { "id": "docs", "label": "Open docs", "value": null, "style": "secondary", "echo": false, "action": { "type": "open_url", "url": "https://docs.example.com" } },
            { "label": "No id" }
          ]
        },
        {
          "id": "c_articles", "type": "articles", "fallback_text": null, "answer": null,
          "articles": [
            { "id": 9, "title": "Install", "description": null, "url": "https://help.example.com/articles/9", "help_center_id": 4 },
            { "id": "ext-1", "title": "External", "description": "Elsewhere", "url": "https://example.com/a", "help_center_id": null }
          ]
        },
        {
          "id": "c_input", "type": "input", "fallback_text": "What's your email?", "answer": null,
          "label": "Email", "kind": "email", "placeholder": "you@example.com", "required": true,
          "options": [], "save_to": "email", "echo": true, "action": { "type": "goto", "step": "next" }
        },
        {
          "id": "c_select", "type": "input", "fallback_text": null,
          "answer": { "button_id": null, "value": "pro", "answered_at": "2026-11-16T10:01:00Z" },
          "label": "Plan", "kind": "select", "placeholder": null, "required": false,
          "options": [{ "value": "basic", "label": "Basic" }, { "value": "pro", "label": "Pro" }], "save_to": "plan", "echo": false, "action": null
        },
        {
          "id": "c_card", "type": "card", "fallback_text": "Upgrade", "answer": null,
          "title": "Upgrade", "body": "Get **more** seats", "image_url": "http://insecure.example.com/i.png",
          "buttons": [{ "id": "go", "label": "Upgrade", "value": null, "style": "primary", "echo": false, "action": { "type": "event", "name": "upgrade" } }]
        },
        { "id": "c_future", "type": "carousel", "fallback_text": "Pick a slide", "answer": null, "slides": [] },
        { "id": "c_silent", "type": "map", "fallback_text": null, "answer": null },
        { "type": "buttons", "buttons": [] }
      ],
      "created_at": "2026-11-16T09:59:00Z"
    }
    """

    @Test func decodesEveryComponentType() throws {
        let message = try Fixtures.decode(Message.self, Self.message)

        #expect(message.author.kind == .bot)
        #expect(message.components.map(\.id) == ["c_buttons", "c_articles", "c_input", "c_select", "c_card", "c_future", "c_silent"])

        guard case let .buttons(buttons) = message.components[0].content else {
            Issue.record("Expected buttons")
            return
        }

        #expect(buttons.layout == .row)
        #expect(buttons.prompt == "Did that help?")
        #expect(buttons.buttons.map(\.id) == ["yes", "no", "docs"])
        #expect(buttons.buttons[0].style == .primary)
        #expect(buttons.buttons[0].echo)
        #expect(buttons.buttons[1].action.kind == .handoff)
        #expect(buttons.buttons[2].opensURL?.absoluteString == "https://docs.example.com")
        #expect(buttons.buttons[0].opensURL == nil)
        #expect(message.components[0].answer?.buttonID == "yes")
        #expect(message.components[0].answer?.answeredAt != nil)

        guard case let .articles(articles) = message.components[1].content else {
            Issue.record("Expected articles")
            return
        }

        #expect(articles.map(\.id) == ["9", "ext-1"])
        #expect(articles[0].articleID == 9)
        #expect(articles[0].helpCenterID == 4)
        #expect(articles[1].articleID == nil)
        #expect(articles[1].helpCenterID == nil)
        #expect(articles[1].description == "Elsewhere")

        guard case let .input(email) = message.components[2].content else {
            Issue.record("Expected an input")
            return
        }

        #expect(email.kind == .email)
        #expect(email.required)
        #expect(email.placeholder == "you@example.com")
        #expect(email.saveTo == "email")
        #expect(email.action?.kind == .goto)
        #expect(email.action?.step == "next")
        #expect(message.components[2].isAnswered == false)

        guard case let .input(select) = message.components[3].content, let answer = message.components[3].answer else {
            Issue.record("Expected an answered select")
            return
        }

        #expect(select.kind == .select)
        #expect(select.options.map(\.label) == ["Basic", "Pro"])
        #expect(select.label(for: answer) == "Pro")

        guard case let .card(card) = message.components[4].content else {
            Issue.record("Expected a card")
            return
        }

        #expect(card.title == "Upgrade")
        #expect(card.body == "Get **more** seats")
        #expect(card.imageURL == nil)
        #expect(card.buttons.first?.action.kind == .event)
        #expect(card.buttons.first?.action.name == "upgrade")
    }

    @Test func unknownTypesKeepTheirFallback() throws {
        let message = try Fixtures.decode(Message.self, Self.message)

        #expect(message.components[5].content == .unknown("carousel"))
        #expect(message.components[5].fallbackText == "Pick a slide")
        #expect(message.components[5].isRenderable)
        #expect(message.components[6].content == .unknown("map"))
        #expect(message.components[6].isRenderable == false)
        #expect(message.isRenderable)
        #expect(message.hasComponents)
        #expect(message.previewText == "Did that help?")
    }

    @Test func missingComponentsDecodeAsEmpty() throws {
        let thread = try Fixtures.decode(ConversationThread.self, Fixtures.thread)

        #expect(thread.messages.allSatisfy { $0.components.isEmpty })

        let json = """
        { "id": "m", "conversation_id": 1, "type": "comment", "author": { "type": "bot", "name": "Kara" },
          "body": "", "components": null, "created_at": "2026-11-16T10:00:00Z" }
        """
        let message = try Fixtures.decode(Message.self, json)

        #expect(message.components.isEmpty)
        #expect(message.isRenderable == false)
    }

    @Test func onlyUnknownWithoutFallbackIsNotRendered() throws {
        let json = """
        { "id": "m", "conversation_id": 1, "type": "comment", "author": { "type": "bot", "name": "Kara" },
          "body": "", "attachments": [], "components": [{ "id": "x", "type": "hologram", "fallback_text": "" }],
          "created_at": "2026-11-16T10:00:00Z" }
        """
        let message = try Fixtures.decode(Message.self, json)

        #expect(message.components.count == 1)
        #expect(message.components[0].fallbackText == nil)
        #expect(message.isRenderable == false)
    }

    @Test func numericAnswersDisplayCleanly() throws {
        let json = #"{ "button_id": null, "value": 42, "answered_at": "2026-11-16T10:00:00Z" }"#
        let answer = try Fixtures.decode(MessageComponent.Answer.self, json)

        #expect(answer.value == .number(42))
        #expect(answer.displayValue == "42")
        #expect(MessageComponent.Answer(buttonID: nil, value: .number(2.5), answeredAt: nil).displayValue == "2.5")
    }

    @Test func interactionsPostToTheMessage() throws {
        let client = APIClient(userAgent: "KaraDesk-iOS/test")
        let request = try client.makeURLRequest(
            .interact(.button("yes", in: "c_buttons"), messageID: "msg_k1", conversationID: 42),
            token: "tok_1"
        )
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(request.url?.absoluteString == "https://api.karadesk.com/v1/messenger/conversations/42/messages/msg_k1/interactions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok_1")
        #expect(json["component_id"] as? String == "c_buttons")
        #expect(json["button_id"] as? String == "yes")
        #expect(json["value"] == nil)
    }

    @Test func inputInteractionsSendTheValue() throws {
        let client = APIClient(userAgent: "KaraDesk-iOS/test")
        let text = try client.makeURLRequest(.interact(.value(.string("a@b.co"), in: "c_input"), messageID: "m", conversationID: 1), token: "t")
        let number = try client.makeURLRequest(.interact(.value(.number(3), in: "c_n"), messageID: "m", conversationID: 1), token: "t")
        let textBody = try #require(text.httpBody)
        let numberBody = try #require(number.httpBody)
        let textJSON = try #require(JSONSerialization.jsonObject(with: textBody) as? [String: Any])
        let numberJSON = try #require(JSONSerialization.jsonObject(with: numberBody) as? [String: Any])

        #expect(textJSON["value"] as? String == "a@b.co")
        #expect(textJSON["button_id"] == nil)
        #expect(numberJSON["value"] as? Int == 3)
    }

    @Test func interactionResultsDecodeWithAndWithoutReply() throws {
        let withReply = try Fixtures.decode(InteractionResult.self, """
        { "message": \(Self.message), "reply": { "id": "msg_k2", "conversation_id": 42, "type": "comment",
          "author": { "type": "bot", "id": "kara", "name": "Kara", "avatar": null },
          "body": "Glad that helped!", "attachments": [], "components": [], "created_at": "2026-11-16T10:00:01Z" } }
        """)
        let withoutReply = try Fixtures.decode(InteractionResult.self, #"{ "message": \#(Self.message), "reply": null }"#)

        #expect(withReply.message.id == "msg_k1")
        #expect(withReply.reply?.body == "Glad that helped!")
        #expect(withoutReply.reply == nil)
    }

    @Test func realtimeUpdatesCarryComponents() throws {
        let json = #"{ "type": "message.updated", "data": { "conversation_id": 42, "message": \#(Self.message) } }"#
        let event = try #require(RealtimeEvent.decode(Data(json.utf8)))

        guard case let .messageUpdated(message) = event else {
            Issue.record("Expected message.updated")
            return
        }

        #expect(message.components.first?.answer?.buttonID == "yes")
    }

    @Test func botTypingDecodes() {
        let event = RealtimeEvent.decode(Data(#"{"type":"typing","data":{"conversation_id":42,"author":{"type":"bot","id":"kara","name":"Kara","avatar":null}}}"#.utf8))

        #expect(event == .typing(conversationID: 42, author: .init(kind: .bot, name: "Kara", avatarURL: nil)))
    }
}
