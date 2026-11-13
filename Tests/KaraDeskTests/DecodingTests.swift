import Foundation
import Testing
@testable import KaraDesk

@Suite("Decoding")
struct DecodingTests {
    @Test func bootResponse() throws {
        let boot = try Fixtures.decode(BootResponse.self, Fixtures.boot)

        #expect(boot.token == "tok_123")
        #expect(boot.space.avatarURL?.absoluteString == "https://cdn.example.com/a.png")
        #expect(boot.identity.type == .user)
        #expect(boot.contact?.role == .user)
        #expect(boot.team.map(\.id) == [1])

        let settings = boot.settings
        #expect(settings.color == "#4F46E5")
        #expect(settings.theme == .dark)
        #expect(settings.logoURL?.host() == "cdn.example.com")
        #expect(settings.background.kind == .gradient)
        #expect(settings.rules(identified: false).singleOpen)
        #expect(settings.rules(identified: false).closedReplyDays == 7)
        #expect(settings.rules(identified: true).allowNew == false)
        #expect(settings.availability?.open == false)
        #expect(settings.attachments.maxBytes == 26_214_400)
        #expect(settings.helpCenter?.articleReactions == true)
    }

    @Test func unknownHomeCardsAreSkipped() throws {
        let boot = try Fixtures.decode(BootResponse.self, Fixtures.boot)

        #expect(boot.settings.homeCards.map(\.id) == ["c1", "c2", "c4"])

        guard case let .help(card) = boot.settings.homeCards[1] else {
            Issue.record("Expected a help card")
            return
        }

        #expect(card.articles.map(\.title) == ["Install"])
    }

    @Test func missingSettingsFallBackToDefaults() throws {
        let json = """
        { "token": "t", "expires_at": "2026-11-20T10:00:00Z", "app": { "id": "a", "name": "A" },
          "space": { "name": "S" }, "settings": {} }
        """
        let boot = try Fixtures.decode(BootResponse.self, json)

        #expect(boot.settings.homeCards.isEmpty)
        #expect(boot.settings.attachments.enabled == false)
        #expect(boot.settings.rules(identified: true) == .standard)
        #expect(boot.identity.type == .visitor)
        #expect(boot.contact == nil)
    }

    @Test func threadSkipsWhatItCannotRender() throws {
        let thread = try Fixtures.decode(ConversationThread.self, Fixtures.thread)

        #expect(thread.conversation.assignee?.name == "Braden")
        #expect(thread.messages.map(\.id) == ["msg_1", "msg_2", "msg_3"])
        #expect(thread.messages[0].attachments.count == 1)
        #expect(thread.messages[2].kind == .other("poll"))

        guard case let .file(file) = thread.messages[0].attachments.first else {
            Issue.record("Expected a file attachment")
            return
        }

        #expect(file.isImage)
        #expect(file.byteSize == 2048)

        guard case let .article(article) = thread.messages[1].attachments.first else {
            Issue.record("Expected an article attachment")
            return
        }

        #expect(article.articleID == 9)
        #expect(article.helpCenterID == 4)
    }

    @Test func datesWithAndWithoutFractions() {
        #expect(Coding.parseDate("2026-11-12T10:00:00.123Z") != nil)
        #expect(Coding.parseDate("2026-11-12T10:00:00Z") != nil)
        #expect(Coding.parseDate("yesterday") == nil)
    }

    @Test func richDocumentKeepsStructure() throws {
        let json = """
        { "type": "doc", "content": [
          { "type": "paragraph", "content": [
            { "type": "text", "text": "Open ", "marks": [] },
            { "type": "text", "text": "Settings", "marks": [{ "type": "bold" }, { "type": "link", "attrs": { "href": "/settings" } }] }
          ]},
          { "type": "image", "attrs": { "src": "https://cdn.example.com/i.png", "width": 320, "align": "right" } }
        ]}
        """
        let doc = try Fixtures.decode(RichNode.self, json)

        #expect(doc.content.count == 2)
        #expect(doc.content[0].content[1].marks.map(\.type) == ["bold", "link"])
        #expect(doc.content[1].attrs["width"]?.numberValue == 320)
        #expect(doc.content[1].attrs["align"]?.stringValue == "right")
    }
}
