import Foundation
import Testing
@testable import KaraDesk

@Suite("Networking")
struct NetworkingTests {
    let client = APIClient(userAgent: "KaraDesk-iOS/test")

    @Test func targetsTheKaraDeskAPI() {
        #expect(APIClient.apiBaseURL.absoluteString == "https://api.karadesk.com")
        #expect(client.baseURL == APIClient.apiBaseURL)
    }

    @Test func authorizedRequestsCarryTheSessionToken() throws {
        let request = try client.makeURLRequest(.conversations(), token: "tok_1")

        #expect(request.url?.absoluteString == "https://api.karadesk.com/v1/messenger/conversations")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok_1")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "KaraDesk-iOS/test")
    }

    @Test func publicRequestsNeverSendTheToken() throws {
        let request = try client.makeURLRequest(.search(helpCenterID: 4, query: "reset password"), token: "tok_1")

        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.url?.query()?.contains("q=reset%20password") == true)
    }

    @Test func bodiesUseSnakeCase() throws {
        let message = OutgoingMessage(body: "Hi", attachments: [.init(assetId: "a1")])
        let request = try client.makeURLRequest(.startConversation(message), token: "tok_1")
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let attachments = try #require(json["attachments"] as? [[String: String]])

        #expect(json["body"] as? String == "Hi")
        #expect(attachments == [["type": "file", "asset_id": "a1"]])
    }

    @Test func bootSendsDeviceDetails() throws {
        let boot = BootRequest(
            spaceId: "sp",
            appId: "app",
            visitorId: "ios-visitor-1",
            userId: "u1",
            device: .init(os: "iOS", osVersion: "26.1", deviceModel: "iPhone17,1", appVersion: "2.0 (5)", sdkVersion: "0.1.0", language: "en-US", timezone: "UTC")
        )
        let request = try client.makeURLRequest(.boot(boot), token: nil)
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let device = try #require(json["device"] as? [String: String])

        #expect(json["space_id"] as? String == "sp")
        #expect(json["visitor_id"] as? String == "ios-visitor-1")
        #expect(json["email"] == nil)
        #expect(device["device_model"] == "iPhone17,1")
        #expect(device["app_version"] == "2.0 (5)")
        #expect(device["sdk_version"] == "0.1.0")
    }

    @Test func errorsMapToKaraDeskErrors() {
        let body = Data(#"{"message":"This messenger isn't available"}"#.utf8)

        #expect(APIClient.error(status: 404, data: body) == .unavailable("This messenger isn't available"))
        #expect(APIClient.error(status: 401, data: Data(#"{"message":"Invalid user hash"}"#.utf8)) == .identityVerificationFailed("Invalid user hash"))
        #expect(APIClient.error(status: 401, data: Data(#"{"message":"Identity verification failed"}"#.utf8)) == .identityVerificationFailed("Identity verification failed"))
        #expect(APIClient.error(status: 401, data: Data()).isExpiredSession)
        #expect(APIClient.error(status: 500, data: Data("oops".utf8)) == .server(statusCode: 500, message: HTTPURLResponse.localizedString(forStatusCode: 500)))
    }

    @Test func multipartFormIncludesFieldsAndFile() throws {
        let data = MultipartForm(boundary: "B")
            .adding(fields: ["key": "spaces/1/a.png", "Policy": "p"])
            .adding(file: Data("PNG".utf8), field: "file", filename: "a\".png", contentType: "image/png")
            .encoded()
        let text = try #require(String(data: data, encoding: .utf8))

        #expect(text.contains("name=\"Policy\"\r\n\r\np\r\n"))
        #expect(text.contains("filename=\"a.png\""))
        #expect(text.contains("Content-Type: image/png\r\n\r\nPNG\r\n"))
        #expect(text.hasSuffix("--B--\r\n"))
    }
}
