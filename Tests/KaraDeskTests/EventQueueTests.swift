import Foundation
import Testing
@testable import KaraDesk

@MainActor
@Suite("Event queue")
struct EventQueueTests {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "karadesk-events-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func makeQueue() -> EventQueue {
        EventQueue(spaceID: "sp", appID: "app", client: APIClient(userAgent: "test"), directory: directory)
    }

    @Test func eventsWaitForASessionThenTakeItsToken() {
        let queue = makeQueue()
        queue.track(name: "Opened app", metadata: [:])

        #expect(queue.events.first?.token == nil)

        queue.setToken("token-a")
        queue.track(name: "Viewed plan", metadata: ["plan": .string("Pro")])

        #expect(queue.events.map(\.token) == ["token-a", "token-a"])
    }

    @Test func eventsKeepTheTokenTheyWereTrackedWith() {
        let queue = makeQueue()
        queue.setToken("token-a")
        queue.track(name: "Before logout", metadata: [:])
        queue.setToken(nil)
        queue.track(name: "After logout", metadata: [:])
        queue.setToken("token-b")

        #expect(queue.events.map(\.token) == ["token-a", "token-b"])
    }

    @Test func keepsAtMostAThousandEventsDroppingTheOldest() {
        let queue = makeQueue()

        for index in 0 ..< 1005 {
            queue.track(name: "Event \(index)", metadata: [:])
        }

        #expect(queue.events.count == EventQueue.maxQueue)
        #expect(queue.events.first?.eventName == "Event 5")
    }

    @Test func survivesARelaunch() {
        let queue = makeQueue()
        queue.setToken("token-a")
        queue.track(name: "Offline event", metadata: ["seats": .number(3)])
        queue.save()

        let reopened = makeQueue()

        #expect(reopened.events.count == 1)
        #expect(reopened.events.first?.eventName == "Offline event")
        #expect(reopened.events.first?.metadata["seats"] == .number(3))
        #expect(reopened.events.first?.token == "token-a")
    }

    @Test func responsesDecideWhatHappensToABatch() {
        let queue = makeQueue()
        queue.setToken("token-a")

        for index in 0 ..< 8 {
            queue.track(name: "Event \(index)", metadata: [:])
        }

        let batch = Array(queue.events.prefix(4))

        queue.handle(batch, status: 500, retryAfter: nil)
        #expect(queue.events.count == 8)

        queue.handle(batch, status: 413, retryAfter: nil)
        #expect(queue.events.count == 8)
        #expect(queue.batchSize == 2)

        queue.handle(batch, status: 200, retryAfter: nil)
        #expect(queue.events.count == 4)
        #expect(queue.batchSize == 4)

        queue.handle(Array(queue.events.prefix(2)), status: 401, retryAfter: nil)
        #expect(queue.events.count == 2)

        queue.handle([queue.events[0]], status: 413, retryAfter: nil)
        #expect(queue.events.count == 1)
    }

    @Test func nestedMetadataLiteralsBecomeJSON() {
        let metadata: [String: KaraDesk.EventValue] = ["order": ["id": "o1", "items": [["sku": "A-100", "quantity": 2]]], "tags": ["new", "promo"]]

        #expect(metadata.mapValues(\.json) == [
            "order": .object(["id": .string("o1"), "items": .array([.object(["sku": .string("A-100"), "quantity": .number(2)])])]),
            "tags": .array([.string("new"), .string("promo")]),
        ])
    }

    @Test func metadataLiteralsBecomeJSON() {
        let metadata: [String: KaraDesk.EventValue] = ["plan": "Pro", "seats": 12, "annual": true, "coupon": nil]

        #expect(metadata.mapValues(\.json) == ["plan": .string("Pro"), "seats": .number(12), "annual": .bool(true), "coupon": .null])
    }
}
