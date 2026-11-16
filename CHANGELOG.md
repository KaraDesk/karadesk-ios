# Changelog

All notable changes to the KaraDesk iOS SDK are documented here. This project follows [Semantic Versioning](https://semver.org).

## 1.1.0

- Messages from Kara, KaraDesk's AI agent, show their interactive parts: reply buttons, suggested articles, a single question field (text, email, phone, number or a choice from a list) and cards. Answers are sent to KaraDesk, the chosen button is marked, and errors such as an invalid email address show under the question. Tapping a suggested article opens it in the help center inside the messenger.
- Image attachments are shown at their own shape, up to 384pt tall, and several images appear as a grid of square thumbnails. Videos show their first frame, a play button and their length.
- Tapping an attachment opens it inside the messenger: images in a full-screen viewer with zoom, swiping between images and sharing (including Save Image), videos in the system player, and other files in Quick Look after downloading. The web view is only used when a file can't be opened.
- File sizes are written the same way as the web messenger, for example "1.5 MB".
- Messages that are only buttons or a card show a useful preview in the conversation list and in-app notifications.
- The home screen's reply time reads "We typically reply in a few minutes" for every reply-time setting.

## 1.0.0

- Errors are explained instead of leaving the messenger spinning. Requests fail right away when the device is offline and give up after 20 seconds otherwise, so sending a message never hangs.
- A "No internet connection" banner shows at the top of the messenger while the device is offline. When the connection returns, the messenger starts again if it couldn't before, or refreshes and reconnects if it was already open.
- Screens that fail to load (starting the messenger, the message list, a conversation, the help center, a collection or an article) explain what went wrong and offer Try again when retrying can help. They no longer show "No messages", "There are no articles yet" or "No articles match your search" when the real problem was a failed request.
- When the messenger is turned off for your space or audience, or your KaraDesk subscription is inactive, users see "Messaging isn't available" instead of a technical message, and the reason is written to the log for you. If that happens while the messenger is open, it switches to the same screen.
- A message that fails to send stays in the composer with a "Not sent" notice explaining why, which can be dismissed. Failed attachment uploads can be retried.
- Server errors show "Something went wrong on our end. Please try again." instead of the server's raw error text.
- Conversations show a spinner while their history loads.
- `KaraDeskError` adds `isOffline` and `isRetryable`, and `.network` errors describe whether the device is offline, the request timed out, or KaraDesk couldn't be reached.

## 0.4.0

- Tapping a KaraDesk notification opens its conversation automatically, with no code in your notification delegate. KaraDesk only acts on its own notifications. Set `KaraDesk.opensConversationsFromNotifications = false` before `initialize` to handle taps yourself with `KaraDesk.handlePush(_:)`.

## 0.3.0

- Push notifications. Pass the APNs device token to `KaraDesk.setDeviceToken(_:)` and add your APNs key in KaraDesk under Settings → Apps, and your users get a push when your team replies while they're away. `KaraDesk.handlePush(_:)` opens the conversation from a notification, and `KaraDesk.presentationOptions(for:)` hides it while the messenger is already open.
- The messenger disconnects from live updates while your app is in the background and reconnects when it returns, so replies arrive as push notifications instead.

## 0.2.0

- New replies show a preview card at the bottom of your app while the messenger is closed, and when someone opens your app with a reply waiting. Tap it to open the conversation, or turn it off with `KaraDesk.showsInAppMessages = false`.
- The home screen falls back to your space avatar when no logo is set.
- Forced light and dark themes now apply to the whole messenger sheet, and brand colors stay readable in both.
- The greeting on the home screen is softer, matching the web messenger.
- Conversation previews update as soon as a reply arrives, and replies in the open conversation are marked read right away.
- Help collections count articles in their sub-collections and hide empty ones.
- The help screen is titled Help.

## 0.1.0

The first release.

- Initialize with `KaraDesk.initialize(spaceID:appID:)`.
- Sign users in and out with `KaraDesk.login(_:)` and `KaraDesk.logout()`, including identity verification.
- Update a signed-in user's details with `KaraDesk.updateUser(_:)`.
- Present the messenger with `KaraDesk.present(_:style:)`, or with the `.karaDesk(isPresented:destination:style:)` SwiftUI modifier.
- Standalone presentation of the help center, an article or a conversation, without tabs.
- Native navigation with Liquid Glass on iOS 26 and the standard system look on earlier versions.
- Home screen with your greeting, team and home cards.
- Conversations with real-time replies, typing indicators, photos, files, shared articles and satisfaction ratings.
- Help center browsing, search and articles with reactions.
- Unread conversation count for badges.
- Privacy manifest.
