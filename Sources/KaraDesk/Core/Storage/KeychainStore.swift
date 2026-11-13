import Foundation
import Security

struct KeychainStore: Sendable {
    let service: String

    init(service: String = "com.karadesk.sdk") {
        self.service = service
    }

    func data(for account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                Log.storage.error("Keychain read failed: \(status, privacy: .public)")
            }

            return nil
        }

        return result as? Data
    }

    func set(_ data: Data, for account: String) {
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            let addStatus = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)

            if addStatus != errSecSuccess {
                Log.storage.error("Keychain write failed: \(addStatus, privacy: .public)")
            }
        } else if status != errSecSuccess {
            Log.storage.error("Keychain update failed: \(status, privacy: .public)")
        }
    }

    func remove(_ account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
