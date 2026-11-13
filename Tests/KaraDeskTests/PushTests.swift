import Foundation
import Testing
@testable import KaraDesk

@Suite("Push")
struct PushTests {
    let client = APIClient(userAgent: "KaraDesk-iOS/test")

    @Test func recognizesKaraDeskPayloads() {
        let payload = PushPayload(userInfo: [
            "aps": ["alert": ["title": "Braden", "body": "Hi"]],
            "karadesk": ["conversation_id": NSNumber(value: 42), "message_id": "msg_1"],
        ])

        #expect(payload == PushPayload(userInfo: ["karadesk": ["conversation_id": 42, "message_id": "msg_1"]]))
        #expect(payload?.conversationID == 42)
        #expect(payload?.messageID == "msg_1")
        #expect(KaraDesk.isKaraDeskPush(["karadesk": ["conversation_id": "7"]]))
    }

    @Test func ignoresOtherNotifications() {
        #expect(PushPayload(userInfo: ["aps": ["alert": "Your order shipped"]]) == nil)
        #expect(PushPayload(userInfo: ["karadesk": ["message_id": "msg_1"]]) == nil)
        #expect(!KaraDesk.isKaraDeskPush(["orderId": 12]))
    }

    @Test func readsTheEnvironmentFromTheProvisioningProfile() {
        #expect(PushEnvironment.fromProfileData(profile(aps: "development")) == .sandbox)
        #expect(PushEnvironment.fromProfileData(profile(aps: "production")) == .production)
        #expect(PushEnvironment.fromProfileData(profile(aps: nil)) == nil)
        #expect(PushEnvironment.fromProfileData(Data("not a profile".utf8)) == nil)
    }

    @Test func registersAndRemovesTokens() throws {
        let register = try client.makeURLRequest(
            .registerPushToken(PushTokenInput(token: "ab12", environment: "sandbox")),
            token: "tok_1"
        )
        let body = try #require(register.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])

        #expect(register.httpMethod == "PUT")
        #expect(register.url?.absoluteString == "https://api.karadesk.com/v1/messenger/push-token")
        #expect(register.value(forHTTPHeaderField: "Authorization") == "Bearer tok_1")
        #expect(json == ["token": "ab12", "environment": "sandbox"])

        let remove = try client.makeURLRequest(.removePushToken("ab12"), token: "tok_1")

        #expect(remove.httpMethod == "DELETE")
        #expect(remove.url?.absoluteString == "https://api.karadesk.com/v1/messenger/push-token/ab12")
    }

    private func profile(aps: String?) -> Data {
        let entitlement = aps.map { "<key>aps-environment</key><string>\($0)</string>" } ?? ""
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>Entitlements</key><dict>\(entitlement)<key>application-identifier</key><string>2Y9T8BTJGT.app.movesquad</string></dict></dict></plist>
        """

        return Data([0x30, 0x82, 0xFF, 0x01]) + Data(plist.utf8) + Data([0x00, 0xA0, 0xFF])
    }
}
