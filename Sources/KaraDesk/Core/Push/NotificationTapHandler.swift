import Foundation
import ObjectiveC
import os
import UserNotifications

enum NotificationTapHandler {
    private typealias DidReceive = @convention(c) (AnyObject, Selector, UNUserNotificationCenter, UNNotificationResponse, @escaping @convention(block) () -> Void) -> Void
    private typealias DidReceiveBlock = @convention(block) (AnyObject, UNUserNotificationCenter, UNNotificationResponse, @escaping @convention(block) () -> Void) -> Void
    private typealias SetDelegate = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
    private typealias SetDelegateBlock = @convention(block) (AnyObject, AnyObject?) -> Void

    private static let didReceiveSelector = #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))
    private static let setDelegateSelector = #selector(setter: UNUserNotificationCenter.delegate)
    private static let state = OSAllocatedUnfairLock(initialState: State())

    private struct State {
        var installed = false
        var hookedClasses: Set<ObjectIdentifier> = []
    }

    static func install() {
        let shouldInstall = state.withLock { state in
            guard !state.installed else {
                return false
            }

            state.installed = true
            return true
        }

        guard shouldInstall else {
            return
        }

        hookSetDelegate()

        let center = UNUserNotificationCenter.current()

        if let delegate = center.delegate {
            hook(delegate)
        } else {
            center.delegate = FallbackDelegate.shared
        }
    }

    static func handle(_ response: UNNotificationResponse) -> Bool {
        guard KaraDesk.opensConversationsFromNotifications,
              response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            return false
        }

        return KaraDesk.handlePush(response.notification.request.content.userInfo)
    }

    private static func hookSetDelegate() {
        guard let method = class_getInstanceMethod(UNUserNotificationCenter.self, setDelegateSelector) else {
            return
        }

        let original = unsafeBitCast(method_getImplementation(method), to: SetDelegate.self)
        let selector = setDelegateSelector
        let replacement: SetDelegateBlock = { center, delegate in
            if let delegate = delegate as? UNUserNotificationCenterDelegate {
                hook(delegate)
            }

            original(center, selector, delegate)
        }

        method_setImplementation(method, imp_implementationWithBlock(replacement))
    }

    static func hook(_ delegate: UNUserNotificationCenterDelegate) {
        guard let delegateClass = object_getClass(delegate) else {
            return
        }

        let isNew = state.withLock { state in
            state.hookedClasses.insert(ObjectIdentifier(delegateClass)).inserted
        }

        guard isNew else {
            return
        }

        let selector = didReceiveSelector

        guard let existing = class_getInstanceMethod(delegateClass, selector) else {
            let added: DidReceiveBlock = { _, _, response, completion in
                _ = handle(response)
                completion()
            }

            class_addMethod(delegateClass, selector, imp_implementationWithBlock(added), "v@:@@@?")
            return
        }

        let original = unsafeBitCast(method_getImplementation(existing), to: DidReceive.self)
        let replacement: DidReceiveBlock = { target, center, response, completion in
            if handle(response) {
                completion()
            } else {
                original(target, selector, center, response, completion)
            }
        }
        let implementation = imp_implementationWithBlock(replacement)

        if !class_addMethod(delegateClass, selector, implementation, method_getTypeEncoding(existing)) {
            method_setImplementation(existing, implementation)
        }
    }
}

private final class FallbackDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = FallbackDelegate()
}
