# KaraDesk for iOS

Add the [KaraDesk](https://karadesk.com) messenger to your iOS app. Your users can chat with your team, get answers from your help center, and pick up their conversations on any device, all inside your app.

- **Native** — built with SwiftUI and Swift Concurrency, with no third-party dependencies.
- **On brand** — uses the colors, logo, greeting and home cards you set in KaraDesk, in light and dark mode.
- **Live** — new replies, typing indicators and unread counts update in real time.
- **Complete** — conversations with photos and files, satisfaction ratings, and your full help center.

## Requirements

- iOS 17 or later
- Xcode 16 or later (Swift 6)

## Installation

KaraDesk is distributed with Swift Package Manager.

In Xcode, choose **File → Add Package Dependencies…**, enter the repository URL, and add the **KaraDesk** library to your app target:

```
https://github.com/KaraDesk/karadesk-ios
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/KaraDesk/karadesk-ios", from: "0.3.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "KaraDesk", package: "karadesk-ios"),
    ]),
]
```

## Quick start

### 1. Initialize

Find your space ID and iOS app ID in KaraDesk under **Settings → Apps**, then initialize KaraDesk once when your app launches.

**SwiftUI**

```swift
import KaraDesk
import SwiftUI

@main
struct MyApp: App {
    init() {
        KaraDesk.initialize(spaceID: "YOUR_SPACE_ID", appID: "YOUR_APP_ID")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**UIKit**

```swift
import KaraDesk

func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    KaraDesk.initialize(spaceID: "YOUR_SPACE_ID", appID: "YOUR_APP_ID")
    return true
}
```

### 2. Open the messenger

```swift
KaraDesk.present()
```

That's it. Until someone signs in, people are treated as anonymous visitors, and anything they send moves to their account when they do.

## Signing users in

When someone signs in to your app, tell KaraDesk who they are so their conversations follow them across devices:

```swift
try await KaraDesk.login(KaraDesk.User(
    id: user.id,
    email: user.email,
    name: user.fullName
))
```

Provide at least an `id` or an `email`. You can also set `phone`, `avatarURL` and `signedUpAt`. Call `login` again on each launch while the user stays signed in.

When the user's details change, update just what changed. Everything you leave out stays the same:

```swift
try await KaraDesk.updateUser(KaraDesk.User(name: "Evangelina Ruiz", avatarURL: newAvatarURL))
```

When they sign out, start a fresh anonymous visitor so the next person on the device can't see their conversations:

```swift
KaraDesk.logout()
```

### Identity verification

Identity verification stops anyone from impersonating your users. Turn it on for your app in KaraDesk, then have **your server** compute an HMAC-SHA256 of the user's id (or their email if they have no id) with the app's identity verification secret, and pass it as `userHash`:

```swift
try await KaraDesk.login(KaraDesk.User(id: user.id, email: user.email, userHash: hashFromYourServer))
```

> [!IMPORTANT]
> Never ship your identity verification secret inside your app. Compute the hash on your server.

## Presenting the messenger

`present()` opens the messenger on its home screen, just like your help button on the web. You can also open it somewhere specific:

```swift
KaraDesk.present(.messages)
KaraDesk.present(.newConversation(message: "I need help with order #1042"))
KaraDesk.present(.conversation(id: 1234))
KaraDesk.present(.helpCenter)
KaraDesk.present(.article(id: 56))

KaraDesk.dismiss()
```

If the messenger is already open, `present` reopens it at the new destination.

### Standalone

By default the messenger opens with its Home, Messages and Help tabs. To show only one part of it, present it standalone:

```swift
KaraDesk.present(.helpCenter, style: .standalone)
KaraDesk.present(.article(id: 56), style: .standalone)
KaraDesk.present(.newConversation(), style: .standalone)
```

A standalone help center still lets people browse and search articles. A standalone article or conversation opens on its own, with nothing to navigate back to.

In SwiftUI you can present it with a binding instead:

```swift
struct SupportButton: View {
    @State private var showsHelp = false

    var body: some View {
        Button("Help") { showsHelp = true }
            .karaDesk(isPresented: $showsHelp, destination: .helpCenter, style: .standalone)
    }
}
```

## Unread conversations

Show a badge when the team has replied. Reading `unreadConversationCount` in a SwiftUI view keeps it up to date automatically:

```swift
Button("Messages") { KaraDesk.present(.messages) }
    .badge(KaraDesk.unreadConversationCount)
```

In UIKit, observe the notification:

```swift
NotificationCenter.default.addObserver(
    forName: KaraDesk.unreadConversationCountDidChangeNotification,
    object: nil,
    queue: .main
) { notification in
    let count = notification.userInfo?[KaraDesk.unreadConversationCountKey] as? Int ?? 0
    // Update your badge
}
```

## In-app message previews

When your team replies while the messenger is closed, a preview card slides up from the bottom of your app. Tapping it opens the conversation. To turn it off:

```swift
KaraDesk.showsInAppMessages = false
```

## Push notifications

KaraDesk can send a push notification when your team replies while the user is away from your app. Tapping it opens the conversation.

### 1. Add your APNs key to KaraDesk

In your Apple Developer account, open Certificates, Identifiers & Profiles → Keys and create a key with Apple Push Notifications service (APNs) enabled. Download the `.p8` file.

In KaraDesk, open Settings → Apps, choose your iOS app and add the key under Push notifications with its Key ID, your Team ID and your app's bundle ID. KaraDesk checks the key with Apple before saving it.

### 2. Turn on push notifications in your app

In Xcode, add the Push Notifications capability to your app target.

### 3. Pass the device token to KaraDesk

KaraDesk never asks for notification permission itself. Ask when it makes sense in your app, register with APNs, and pass the token along:

```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    KaraDesk.setDeviceToken(deviceToken)
}
```

KaraDesk keeps the token linked to whoever is signed in. It moves to the new user after `login`, and stops after `logout`.

### 4. Open conversations from notifications

In your `UNUserNotificationCenterDelegate`, let KaraDesk handle its own notifications:

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    if KaraDesk.handlePush(response.notification.request.content.userInfo) {
        return
    }

    // Handle your own notifications.
}

func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
    if let options = await KaraDesk.presentationOptions(for: notification.request.content.userInfo) {
        return options
    }

    return [.banner, .list, .sound]
}
```

`presentationOptions(for:)` hides the notification while the messenger is open, since the reply already shows there. Use `KaraDesk.isKaraDeskPush(_:)` anywhere else you need to tell KaraDesk notifications apart from your own.

Debug builds from Xcode use Apple's sandbox push environment and App Store and TestFlight builds use production. KaraDesk detects this for you.

## Errors

`login` and `updateUser` throw a `KaraDeskError`:

| Error | Meaning |
| --- | --- |
| `.notInitialized` | `KaraDesk.initialize` hasn't been called yet. |
| `.notLoggedIn` | `updateUser` was called before `login`. |
| `.identityVerificationFailed` | The user hash is missing or doesn't match. |
| `.unavailable` | The messenger is turned off for this audience, or the KaraDesk subscription is inactive. |
| `.network` | The device couldn't reach KaraDesk. |
| `.server` | KaraDesk returned an error. |

## Privacy

KaraDesk includes a privacy manifest (`PrivacyInfo.xcprivacy`) describing the data it collects, so App Store Connect can include it in your app's privacy report. KaraDesk doesn't track users across apps, doesn't use the advertising identifier, and only collects what's needed to provide support:

- The name, email, phone and user id you pass to `login`
- Messages, photos and files your users send
- Device model, iOS version, app version, language and time zone
- The push token iOS gives your app, if you pass it to `setDeviceToken`

Picking photos and files uses the system pickers, so your app doesn't need photo library or file access permissions.

## Support

Questions or problems? Reach us through the messenger at [karadesk.com](https://karadesk.com).

## License

The KaraDesk iOS SDK is available under the [Apache License 2.0](LICENSE). Copyright 2026 Boothby Lab LLC.

KaraDesk and the KaraDesk logo are trademarks of Boothby Lab LLC.
