import Foundation
import Testing
@testable import KaraDesk

@Suite("Realtime")
struct RealtimeTests {
    @Test func decodesMessageEvents() throws {
        let json = """
        { "type": "message.created", "data": { "conversation_id": 42, "message": {
          "id": "msg_9", "conversation_id": 42, "type": "comment",
          "author": { "type": "user", "id": 1, "name": "Braden", "avatar": null },
          "body": "On it", "attachments": [], "created_at": "2026-11-12T10:05:00Z" } } }
        """
        let event = try #require(RealtimeEvent.decode(Data(json.utf8)))

        guard case let .messageCreated(message) = event else {
            Issue.record("Expected message.created")
            return
        }

        #expect(message.body == "On it")
    }

    @Test func decodesTypingAndDeletes() {
        let typing = RealtimeEvent.decode(Data(#"{"type":"typing","data":{"conversation_id":3,"author":{"type":"user","name":"Ann"}}}"#.utf8))
        let deleted = RealtimeEvent.decode(Data(#"{"type":"message.deleted","data":{"conversation_id":3,"message_id":"m1"}}"#.utf8))

        #expect(typing == .typing(conversationID: 3, author: .init(kind: .user, name: "Ann", avatarURL: nil)))
        #expect(deleted == .messageDeleted(conversationID: 3, messageID: "m1"))
    }

    @Test func ignoresUnknownOrBrokenEvents() {
        #expect(RealtimeEvent.decode(Data(#"{"type":"presence.changed","data":{}}"#.utf8)) == nil)
        #expect(RealtimeEvent.decode(Data(#"{"type":"message.created","data":{"oops":true}}"#.utf8)) == nil)
        #expect(RealtimeEvent.decode(Data("not json".utf8)) == nil)
    }

    @Test func backoffGrowsAndCaps() {
        let first = RealtimeConnection.backoff(attempt: 1)
        let late = RealtimeConnection.backoff(attempt: 40)

        #expect(first >= .seconds(2) && first <= .milliseconds(2600))
        #expect(late >= .seconds(30) && late <= .seconds(39))
    }
}
