# Changelog

All notable changes to the KaraDesk iOS SDK are documented here. This project follows [Semantic Versioning](https://semver.org).

## Unreleased

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
