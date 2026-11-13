import Foundation
import UIKit
import UserNotifications

extension KaraDesk {
    /// Registers this device for KaraDesk push notifications.
    ///
    /// Pass the token iOS gives your app delegate. KaraDesk sends a push when your team replies
    /// while the user is away from your app, using the APNs key you add in KaraDesk under
    /// Settings → Apps.
    ///
    /// ```swift
    /// func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    ///     KaraDesk.setDeviceToken(deviceToken)
    /// }
    /// ```
    ///
    /// KaraDesk never asks for notification permission itself. Ask when it makes sense in your app,
    /// then call `UIApplication.shared.registerForRemoteNotifications()`.
    public static func setDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()

        guard !token.isEmpty else {
            return
        }

        pendingPushToken = token
        store?.setPushToken(token)
    }

    /// Whether a notification came from KaraDesk.
    ///
    /// Use this in your notification delegate to pass KaraDesk notifications to
    /// ``handlePush(_:)`` and handle your own as usual.
    public nonisolated static func isKaraDeskPush(_ userInfo: [AnyHashable: Any]) -> Bool {
        PushPayload(userInfo: userInfo) != nil
    }

    /// Opens the conversation a KaraDesk notification is about.
    ///
    /// Call this when the user taps a notification. It returns `false` and does nothing for
    /// notifications that didn't come from KaraDesk.
    ///
    /// ```swift
    /// func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    ///     if KaraDesk.handlePush(response.notification.request.content.userInfo) {
    ///         return
    ///     }
    ///     // Handle your own notifications.
    /// }
    /// ```
    @discardableResult
    public nonisolated static func handlePush(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let payload = PushPayload(userInfo: userInfo) else {
            return false
        }

        Task { @MainActor in
            whenActive {
                present(.conversation(id: payload.conversationID))
            }
        }

        return true
    }

    /// How to show a KaraDesk notification that arrives while your app is open.
    ///
    /// The notification is hidden while the messenger is on screen, since the reply already shows
    /// there. Otherwise it appears as a banner. Returns `nil` for notifications that didn't come
    /// from KaraDesk.
    ///
    /// ```swift
    /// func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
    ///     if let options = await KaraDesk.presentationOptions(for: notification.request.content.userInfo) {
    ///         return options
    ///     }
    ///     return [.banner, .list, .sound]
    /// }
    /// ```
    public nonisolated static func presentationOptions(for userInfo: [AnyHashable: Any]) async -> UNNotificationPresentationOptions? {
        guard PushPayload(userInfo: userInfo) != nil else {
            return nil
        }

        return await MainActor.run {
            if let store {
                Task { await store.refreshAndAnnounce() }
            }

            return isPresented ? [] : [.banner, .list, .sound]
        }
    }

    static var pendingPushToken: String?

    private static func whenActive(_ action: @escaping @MainActor () -> Void) {
        guard UIApplication.shared.applicationState != .active else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { action() }
            }
            return
        }

        var observer: (any NSObjectProtocol)?
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }

            MainActor.assumeIsolated { action() }
        }
    }
}
