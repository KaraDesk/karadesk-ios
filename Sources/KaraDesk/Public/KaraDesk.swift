import Foundation

/// The entry point to the KaraDesk messenger.
///
/// Initialize KaraDesk once when your app launches, then present the messenger wherever your
/// users need help:
///
/// ```swift
/// KaraDesk.initialize(spaceID: "your-space-id", appID: "your-ios-app-id")
/// ```
@MainActor
public enum KaraDesk {
    /// Posted on the main thread whenever the number of unread conversations changes.
    ///
    /// The new count is in the notification's `userInfo` under ``unreadConversationCountKey``.
    public static let unreadConversationCountDidChangeNotification = Notification.Name("KaraDeskUnreadConversationCountDidChange")

    /// The `userInfo` key holding the unread conversation count in ``unreadConversationCountDidChangeNotification``.
    public static let unreadConversationCountKey = "count"

    /// The version of the KaraDesk SDK.
    public nonisolated static let version = SDKVersion.current

    static private(set) var store: MessengerStore?

    /// Connects the SDK to your KaraDesk space.
    ///
    /// Call this once, as early as possible, for example in `application(_:didFinishLaunchingWithOptions:)`
    /// or your SwiftUI `App` initializer. Find both identifiers in KaraDesk under Settings → Apps.
    ///
    /// - Parameters:
    ///   - spaceID: The identifier of your KaraDesk space.
    ///   - appID: The identifier of your iOS app in KaraDesk.
    public static func initialize(spaceID: String, appID: String) {
        let spaceID = spaceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let appID = appID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !spaceID.isEmpty, !appID.isEmpty else {
            assertionFailure(KaraDeskError.invalidConfiguration.localizedDescription)
            return
        }

        if let store, store.spaceID == spaceID, store.appID == appID {
            return
        }

        let store = MessengerStore(
            spaceID: spaceID,
            appID: appID,
            client: APIClient(userAgent: DeviceContext.userAgent()),
            identity: IdentityStore(spaceID: spaceID, appID: appID),
            device: { DeviceContext.current() }
        )

        store.onUnreadCountChange = { count in
            NotificationCenter.default.post(
                name: unreadConversationCountDidChangeNotification,
                object: nil,
                userInfo: [unreadConversationCountKey: count]
            )
        }

        self.store = store

        Task {
            try? await store.start()
        }
    }

    /// Signs in a user of your app so their conversations follow them across devices.
    ///
    /// Call this after your own sign-in completes, and again on each launch while the user stays
    /// signed in. Anything the user started before signing in moves to their account.
    public static func login(_ user: User) async throws(KaraDeskError) {
        guard let store else {
            throw .notInitialized
        }

        guard user.isIdentifiable else {
            throw .identityVerificationFailed(String(
                localized: "error.user.identifier",
                defaultValue: "A user needs an id or an email.",
                bundle: .module
            ))
        }

        try await store.login(user)
    }

    /// Updates details of the signed-in user, such as their name or avatar.
    ///
    /// Only the properties you set are changed; everything else stays as it was. The user's
    /// identity can't change here. To switch to a different person, call ``login(_:)``.
    ///
    /// ```swift
    /// try await KaraDesk.updateUser(KaraDesk.User(name: "Evangelina Ruiz", avatarURL: newAvatarURL))
    /// ```
    public static func updateUser(_ changes: User) async throws(KaraDeskError) {
        guard let store else {
            throw .notInitialized
        }

        try await store.update(changes)
    }

    /// Signs the current user out and starts a fresh anonymous visitor.
    ///
    /// Call this when the user signs out of your app so the next person on this device can't see
    /// their conversations.
    public static func logout() {
        store?.logout()

        Task {
            try? await store?.start()
        }
    }

    /// The number of conversations with replies the user hasn't seen yet.
    ///
    /// Reading this from a SwiftUI view keeps the view up to date automatically.
    public static var unreadConversationCount: Int {
        store?.unreadConversationCount ?? 0
    }
}
