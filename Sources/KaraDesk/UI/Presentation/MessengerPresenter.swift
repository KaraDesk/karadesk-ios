import SwiftUI
import UIKit

@MainActor
final class MessengerPresenter {
    static let shared = MessengerPresenter()

    private weak var controller: UIViewController?

    var isPresented: Bool {
        controller?.presentingViewController != nil
    }

    func present(_ destination: KaraDesk.Destination, style: KaraDesk.PresentationStyle, store: MessengerStore) {
        if let controller, controller.presentingViewController != nil {
            controller.dismiss(animated: true) { [weak self] in
                self?.controller = nil
                self?.present(destination, style: style, store: store)
            }
            return
        }

        guard let presenter = Self.topViewController() else {
            Log.session.error("No window is available to present the messenger from")
            return
        }

        let view = MessengerView(store: store, destination: destination, style: style) { [weak self] in
            self?.dismiss()
        }
        let host = UIHostingController(rootView: view)
        host.modalPresentationStyle = .pageSheet
        host.sheetPresentationController?.prefersGrabberVisible = false

        controller = host
        presenter.present(host, animated: true)
    }

    func dismiss() {
        controller?.dismiss(animated: true)
        controller = nil
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let candidates = scenes
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .filter { !($0 is PassthroughWindow) }
        let window = candidates.first(where: \.isKeyWindow)
            ?? candidates.first { !$0.isHidden && $0.windowLevel == .normal }
            ?? scenes.flatMap(\.windows).first { !($0 is PassthroughWindow) && $0.isKeyWindow }

        var top = window?.rootViewController

        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }

        return top
    }
}
