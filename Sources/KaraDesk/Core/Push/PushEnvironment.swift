import Foundation

enum PushEnvironment: String, Sendable {
    case production
    case sandbox

    static let current: PushEnvironment = {
        #if targetEnvironment(simulator)
        return .sandbox
        #else
        return fromProvisioningProfile() ?? .production
        #endif
    }()

    static func fromProvisioningProfile(bundle: Bundle = .main) -> PushEnvironment? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return fromProfileData(data)
    }

    static func fromProfileData(_ data: Data) -> PushEnvironment? {
        guard let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<plist"),
              let end = text.range(of: "</plist>", range: start.upperBound ..< text.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: Data(text[start.lowerBound ..< end.upperBound].utf8),
                  format: nil
              ) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let aps = entitlements["aps-environment"] as? String else {
            return nil
        }

        return aps == "development" ? .sandbox : .production
    }
}

struct PushPayload: Sendable, Equatable {
    let conversationID: Int
    let messageID: String?

    init?(userInfo: [AnyHashable: Any]) {
        guard let karadesk = userInfo["karadesk"] as? [String: Any] else {
            return nil
        }

        let rawID = karadesk["conversation_id"]
        let id = (rawID as? Int) ?? (rawID as? NSNumber)?.intValue ?? (rawID as? String).flatMap(Int.init)

        guard let id else {
            return nil
        }

        conversationID = id
        messageID = karadesk["message_id"] as? String
    }
}
