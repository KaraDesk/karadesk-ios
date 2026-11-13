import Foundation

struct IdentityStore: Sendable {
    private let keychain: KeychainStore
    private let scope: String

    init(spaceID: String, appID: String, keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
        self.scope = "\(spaceID).\(appID)"
    }

    func visitorID() -> String {
        if let data = keychain.data(for: visitorAccount), let id = String(data: data, encoding: .utf8), !id.isEmpty {
            return id
        }

        return rotateVisitorID()
    }

    @discardableResult
    func rotateVisitorID() -> String {
        let id = "ios-\(UUID().uuidString.lowercased())"
        keychain.set(Data(id.utf8), for: visitorAccount)
        return id
    }

    func user() -> KaraDesk.User? {
        guard let data = keychain.data(for: userAccount) else {
            return nil
        }

        return try? JSONDecoder().decode(KaraDesk.User.self, from: data)
    }

    func setUser(_ user: KaraDesk.User?) {
        guard let user, let data = try? JSONEncoder().encode(user) else {
            keychain.remove(userAccount)
            return
        }

        keychain.set(data, for: userAccount)
    }

    private var visitorAccount: String {
        "visitor.\(scope)"
    }

    private var userAccount: String {
        "user.\(scope)"
    }
}
