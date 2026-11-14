import Foundation
import os
import UIKit
import UserNotifications

extension KaraDesk {
    /// Whether tapping a KaraDesk notification opens its conversation automatically. Defaults to `true`.
    ///
    /// KaraDesk attaches to your app's `UNUserNotificationCenter` delegate when you call
    /// ``initialize(spaceID:appID:)`` and only acts on its own notifications. Every other
    /// notification reaches your delegate as usual. Set this to `false` before calling
    /// ``initialize(spaceID:appID:)`` to call ``handlePush(_:)`` yourself instead.
    nonisolated(unsafe) public static var opensConversationsFromNotifications = true

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
    /// KaraDesk does this for you when a notification is tapped, unless you turned off
    /// ``opensConversationsFromNotifications``. It returns `false` and does nothing for
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

        guard recentlyHandled.claim(payload) else {
            return true
        }

        Task { @MainActor in
            guard store != nil else {
                return
            }

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

    private nonisolated static let recentlyHandled = HandledPushes()

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

private final class HandledPushes: Sendable {
    private let last = OSAllocatedUnfairLock<(payload: PushPayload, at: Date)?>(initialState: nil)

    func claim(_ payload: PushPayload) -> Bool {
        last.withLock { last in
            if let previous = last, previous.payload == payload, Date().timeIntervalSince(previous.at) < 2 {
                return false
            }

            last = (payload, Date())
            return true
        }
    }
}
