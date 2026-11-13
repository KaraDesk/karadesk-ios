import Foundation

extension KaraDesk {
    /// A signed-in user of your app.
    ///
    /// Provide at least an ``id`` or an ``email``. When identity verification is turned on
    /// for your app in KaraDesk, also provide the ``userHash`` your server computed for this user.
    public struct User: Sendable, Hashable, Codable {
        /// Your app's stable identifier for this user.
        public var id: String?

        /// The user's email address.
        public var email: String?

        /// The user's full name.
        public var name: String?

        /// The user's phone number.
        public var phone: String?

        /// A public HTTPS URL of the user's avatar.
        public var avatarURL: URL?

        /// When the user signed up for your app.
        public var signedUpAt: Date?

        /// The HMAC-SHA256 of the user's ``id`` (or ``email`` when there is no id), computed on your
        /// server with the app's identity verification secret.
        public var userHash: String?

        public init(
            id: String? = nil,
            email: String? = nil,
            name: String? = nil,
            phone: String? = nil,
            avatarURL: URL? = nil,
            signedUpAt: Date? = nil,
            userHash: String? = nil
        ) {
            self.id = id
            self.email = email
            self.name = name
            self.phone = phone
            self.avatarURL = avatarURL
            self.signedUpAt = signedUpAt
            self.userHash = userHash
        }

        func merging(_ changes: User) -> User {
            User(
                id: id ?? changes.id,
                email: changes.email ?? email,
                name: changes.name ?? name,
                phone: changes.phone ?? phone,
                avatarURL: changes.avatarURL ?? avatarURL,
                signedUpAt: changes.signedUpAt ?? signedUpAt,
                userHash: changes.userHash ?? userHash
            )
        }

        var isIdentifiable: Bool {
            !(id ?? "").isEmpty || !(email ?? "").isEmpty
        }
    }
}
