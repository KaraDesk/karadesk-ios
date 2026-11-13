import SwiftUI
import UIKit

extension KaraDesk {
    /// A place in the messenger to open.
    public enum Destination: Sendable, Hashable {
        /// The messenger home, as if the user tapped your help button. This is the default.
        case home

        /// The list of the user's conversations.
        case messages

        /// A new conversation, optionally with the composer pre-filled.
        case newConversation(message: String? = nil)

        /// An existing conversation.
        case conversation(id: Int)

        /// The help center.
        case helpCenter

        /// A help center article.
        case article(id: Int)
    }

    /// How the messenger is shown.
    public enum PresentationStyle: Sendable, Hashable {
        /// The full messenger, with Home, Messages and Help tabs. This is the default.
        case standard

        /// Only the destination, without tabs. A conversation or an article opens on its own,
        /// and the help center lets people browse and search articles without leaving it.
        case standalone
    }

    /// Shows the messenger over your app's current screen.
    ///
    /// ```swift
    /// KaraDesk.present()
    /// KaraDesk.present(.newConversation(message: "I need help with my order"))
    /// KaraDesk.present(.helpCenter, style: .standalone)
    /// ```
    ///
    /// If the messenger is already open, it closes and reopens at `destination`.
    public static func present(_ destination: Destination = .home, style: PresentationStyle = .standard) {
        guard let store else {
            assertionFailure(KaraDeskError.notInitialized.localizedDescription)
            return
        }

        MessengerPresenter.shared.present(destination, style: style, store: store)
    }

    /// Closes the messenger if it is open.
    public static func dismiss() {
        MessengerPresenter.shared.dismiss()
    }

    /// Whether the messenger is currently on screen.
    public static var isPresented: Bool {
        MessengerPresenter.shared.isPresented
    }
}

extension View {
    /// Presents the KaraDesk messenger as a sheet while `isPresented` is `true`.
    ///
    /// ```swift
    /// Button("Help") { showHelp = true }
    ///     .karaDesk(isPresented: $showHelp)
    /// ```
    public func karaDesk(
        isPresented: Binding<Bool>,
        destination: KaraDesk.Destination = .home,
        style: KaraDesk.PresentationStyle = .standard
    ) -> some View {
        modifier(MessengerSheetModifier(isPresented: isPresented, destination: destination, style: style))
    }
}

private struct MessengerSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let destination: KaraDesk.Destination
    let style: KaraDesk.PresentationStyle

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            if let store = KaraDesk.store {
                MessengerView(store: store, destination: destination, style: style) {
                    isPresented = false
                }
            }
        }
    }
}
